<?php

declare(strict_types=1);

namespace Tests\Feature\SyncMerge;

use App\Models\Customer;
use App\Models\FieldChange;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Otomatik çakışma birleştirme.
 *
 * Sürüm uyuşmazlığı "aynı anda düzenlendi" demek; "aynı ŞEY düzenlendi"
 * demek değil. Ofis müşterinin telefonunu, saha görevlisi notunu
 * değiştirmişse kimse kimsenin işini ezmiyor — ikisi de uygulanabilir ve
 * kimsenin karar vermesi gerekmiyor.
 *
 * Elle çözüm yalnızca AYNI alan iki tarafta da değiştiğinde gerekli.
 */
class SyncMergeTest extends TestCase
{
    use RefreshDatabase;

    private function kullanici(): User
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        return $user;
    }

    /**
     * Asıl kazanç: farklı alanlara dokunan iki düzenleme otomatik
     * birleşiyor, kimse elle karar vermiyor.
     */
    public function test_edits_to_different_fields_merge_automatically(): void
    {
        $user = $this->kullanici();
        $customer = Customer::factory()->create([
            'company_id' => $user->company_id,
            'notes' => 'Orijinal not',
            'phone' => '05000000000',
        ]);

        // Ofis telefonu değiştirir — sürüm 1 -> 2.
        $this->putJson("/api/v1/customers/{$customer->id}", [
            'base_version' => 1,
            'phone' => '05551112233',
            'changed_fields' => ['phone'],
        ])->assertOk();

        // Telefon hâlâ sürüm 1'i biliyor ve NOTU değiştiriyor. Yük eski
        // telefon numarasını da taşıyor — istemci kaydın tamamını
        // gönderiyor — ama onu değiştirmediğini bildiriyor.
        $this->putJson("/api/v1/customers/{$customer->id}", [
            'base_version' => 1,
            'notes' => 'Sahadan gelen not',
            'phone' => '05000000000',
            'changed_fields' => ['notes'],
        ])->assertOk();

        // İKİSİ de duruyor: çakışma kaydı yok, kimse elle karar vermedi.
        $this->assertDatabaseHas('customers', [
            'id' => $customer->id,
            'notes' => 'Sahadan gelen not',
            'phone' => '05551112233',
        ]);
        $this->assertDatabaseCount('sync_conflicts', 0);
    }

    /**
     * Aynı alana iki taraf da dokunduysa karar insana ait. Otomatik
     * birleştirmenin sınırı tam olarak burası.
     */
    public function test_edits_to_the_same_field_still_become_a_conflict(): void
    {
        $user = $this->kullanici();
        $customer = Customer::factory()->create([
            'company_id' => $user->company_id,
            'notes' => 'Orijinal not',
        ]);

        $this->putJson("/api/v1/customers/{$customer->id}", [
            'base_version' => 1,
            'notes' => 'Ofisin notu',
            'changed_fields' => ['notes'],
        ])->assertOk();

        $this->putJson("/api/v1/customers/{$customer->id}", [
            'base_version' => 1,
            'notes' => 'Sahanın notu',
            'changed_fields' => ['notes'],
        ])->assertConflict();

        // Sunucudaki değer EZİLMEMİŞ.
        $this->assertDatabaseHas('customers', ['id' => $customer->id, 'notes' => 'Ofisin notu']);
        $this->assertDatabaseCount('sync_conflicts', 1);
    }

    /**
     * Birleştirme yalnızca BİLDİRİLEN alanları uygular.
     *
     * Yükün geri kalanı istemcinin eski görüşü. Uygulanırsa sunucudaki
     * yeni değerlerin üzerine yazar ve birleştirmenin anlamı kalmaz —
     * "birleştirdik" deyip veri kaybettirmek, çakışma göstermekten daha
     * kötü.
     */
    public function test_a_merge_does_not_write_back_the_clients_stale_view_of_other_fields(): void
    {
        $user = $this->kullanici();
        $customer = Customer::factory()->create([
            'company_id' => $user->company_id,
            'phone' => '05000000000',
            'address' => 'Eski adres',
        ]);

        $this->putJson("/api/v1/customers/{$customer->id}", [
            'base_version' => 1,
            'address' => 'Ofisin yazdığı yeni adres',
            'changed_fields' => ['address'],
        ])->assertOk();

        $this->putJson("/api/v1/customers/{$customer->id}", [
            'base_version' => 1,
            'phone' => '05551112233',
            'address' => 'Eski adres',
            'changed_fields' => ['phone'],
        ])->assertOk();

        $this->assertDatabaseHas('customers', [
            'id' => $customer->id,
            'phone' => '05551112233',
            'address' => 'Ofisin yazdığı yeni adres',
        ]);
    }

    /**
     * Eski uygulama sürümleri `changed_fields` göndermiyor. Onlar için
     * davranış DEĞİŞMEMELİ: hangi alanları değiştirdiklerini bilmeden
     * birleştirmek tahmin yürütmek olurdu.
     */
    public function test_a_client_that_does_not_report_changed_fields_still_gets_a_conflict(): void
    {
        $user = $this->kullanici();
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->putJson("/api/v1/customers/{$customer->id}", [
            'base_version' => 1,
            'phone' => '05551112233',
            'changed_fields' => ['phone'],
        ])->assertOk();

        $this->putJson("/api/v1/customers/{$customer->id}", [
            'base_version' => 1,
            'notes' => 'Eski istemciden not',
        ])->assertConflict();
    }

    /**
     * İz budanmışsa birleştirme REDDEDİLİR.
     *
     * İz eksikken "sunucu bir şey değiştirmedi" sonucuna varmak, görünmeyen
     * bir değişikliği sessizce ezmek olurdu — bu mekanizmanın engellemek
     * için var olduğu şeyin ta kendisi.
     */
    public function test_merging_is_refused_when_the_field_trail_was_pruned(): void
    {
        $user = $this->kullanici();
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->putJson("/api/v1/customers/{$customer->id}", [
            'base_version' => 1,
            'phone' => '05551112233',
            'changed_fields' => ['phone'],
        ])->assertOk();

        FieldChange::query()->delete();

        $this->putJson("/api/v1/customers/{$customer->id}", [
            'base_version' => 1,
            'notes' => 'Sahadan not',
            'changed_fields' => ['notes'],
        ])->assertConflict();
    }

    /**
     * İz web panelinden yapılan değişiklikleri de kapsıyor.
     *
     * İz kontrolörde tutulsaydı yalnızca API üzerinden yapılanlar kayda
     * geçerdi; panelden yapılan bir değişiklik "olmamış" sayılır ve mobil
     * güncellemesi onu sessizce ezerdi. Bu yüzden sürüm sayacıyla aynı
     * yerde — modelde — tutuluyor.
     */
    public function test_the_trail_also_covers_changes_made_outside_the_api(): void
    {
        $user = $this->kullanici();
        $customer = Customer::factory()->create([
            'company_id' => $user->company_id,
            'notes' => 'Orijinal not',
        ]);

        // Panel/tinker yolu: doğrudan model üzerinden.
        $customer->update(['notes' => 'Panelden yazılan not']);

        $this->assertDatabaseHas('field_changes', [
            'subject_type' => 'customers',
            'subject_id' => $customer->id,
            'version' => 2,
        ]);

        $this->putJson("/api/v1/customers/{$customer->id}", [
            'base_version' => 1,
            'notes' => 'Sahadan not',
            'changed_fields' => ['notes'],
        ])->assertConflict();
    }

    /**
     * Sürüm sayacı ve zaman damgası ize GİRMEZ. Girselerdi her güncelleme
     * "aynı alan iki tarafta da değişti" görünür ve hiçbir şey otomatik
     * çözülemezdi.
     */
    public function test_the_trail_ignores_the_version_counter_and_timestamps(): void
    {
        $user = $this->kullanici();
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $customer->update(['notes' => 'Not']);

        $iz = FieldChange::query()->where('subject_id', $customer->id)->firstOrFail();

        $this->assertSame(['notes'], $iz->fields);
    }
}
