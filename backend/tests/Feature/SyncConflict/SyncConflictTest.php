<?php

declare(strict_types=1);

namespace Tests\Feature\SyncConflict;

use App\Models\Customer;
use App\Models\Job;
use App\Models\SyncConflict;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Bkz. ROADMAP.md § B10 — asıl senaryo: telefon offline'ken ofis aynı
 * kaydı değiştirmiş. Mobilin eski `base_version` ile gönderdiği
 * güncelleme SESSİZCE EZİLMEMELİ — 409 dönmeli ve bir SyncConflict
 * kaydına düşmelidir.
 */
class SyncConflictTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_stale_update_is_rejected_with_409_instead_of_silently_overwriting(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id, 'notes' => 'Orijinal not']);

        // "Ofis" aynı müşteriyi günceller — version 1 -> 2.
        $this->putJson("/api/v1/customers/{$customer->id}", ['base_version' => 1, 'notes' => 'Ofis güncellemesi'])
            ->assertOk();

        // "Telefon" hâlâ eski version'ı (1) biliyor ve offline'ken aldığı
        // notu göndermeye çalışıyor.
        $response = $this->putJson("/api/v1/customers/{$customer->id}", ['base_version' => 1, 'notes' => 'Telefonun offline notu']);

        $response->assertConflict();

        // Sunucudaki veri EZİLMEMİŞ olmalı — ofisin yazdığı hâlâ duruyor.
        $this->assertDatabaseHas('customers', ['id' => $customer->id, 'notes' => 'Ofis güncellemesi']);

        $this->assertDatabaseHas('sync_conflicts', [
            'company_id' => $user->company_id,
            'subject_type' => 'customer',
            'subject_id' => $customer->id,
            'base_version' => 1,
            'server_version' => 2,
            'resolution' => 'BEKLIYOR',
        ]);
    }

    public function test_job_update_conflict_does_not_trigger_ledger_side_effects(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $job = Job::factory()->create(['company_id' => $user->company_id, 'status' => 'DEVAM_EDIYOR']);

        $this->putJson("/api/v1/jobs/{$job->id}", ['base_version' => 1, 'notes' => 'ofis notu'])->assertOk();

        // Telefon, eski version ile işi TAMAMLANDI yapmaya çalışıyor.
        $this->putJson("/api/v1/jobs/{$job->id}", ['base_version' => 1, 'status' => 'TAMAMLANDI', 'actual_price_minor' => 100000])
            ->assertConflict();

        // Çakışma reddedildiği için cari hesaba borç kaydı OLUŞMAMALI.
        $this->assertDatabaseMissing('customer_ledger_entries', ['reference_type' => 'job', 'reference_id' => $job->id]);
        $this->assertDatabaseHas('jobs', ['id' => $job->id, 'status' => 'DEVAM_EDIYOR']);
    }

    public function test_owner_can_list_conflicts_and_resolve_by_keeping_server_version(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id, 'notes' => 'Başlangıç']);

        // Not: Eloquent, gerçek bir değişiklik olmadan `update()` çağrılırsa
        // "dirty" attribute bulamayıp SQL'i (ve dolayısıyla version artışını)
        // atlar — bu yüzden burada ilk isteğin değeri, başlangıç değerinden
        // FARKLI olmalı, aksi halde version hiç artmaz.
        $this->putJson("/api/v1/customers/{$customer->id}", ['base_version' => 1, 'notes' => 'Sunucu hali'])->assertOk();
        $this->putJson("/api/v1/customers/{$customer->id}", ['base_version' => 1, 'notes' => 'Mobil hali'])->assertConflict();

        $conflict = SyncConflict::firstOrFail();

        $this->getJson('/api/v1/sync-conflicts')->assertOk()->assertJsonCount(1, 'data');

        $this->postJson("/api/v1/sync-conflicts/{$conflict->id}/resolve", ['resolution' => 'SUNUCU_TUTULDU'])
            ->assertOk()
            ->assertJsonPath('data.resolution', 'SUNUCU_TUTULDU');

        $this->assertDatabaseHas('customers', ['id' => $customer->id, 'notes' => 'Sunucu hali']);
    }

    public function test_owner_can_resolve_by_keeping_mobile_version(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->putJson("/api/v1/customers/{$customer->id}", ['base_version' => 1, 'notes' => 'Sunucu hali'])->assertOk();
        $this->putJson("/api/v1/customers/{$customer->id}", ['base_version' => 1, 'notes' => 'Mobil hali'])->assertConflict();

        $conflict = SyncConflict::firstOrFail();

        $this->postJson("/api/v1/sync-conflicts/{$conflict->id}/resolve", ['resolution' => 'MOBIL_TUTULDU'])
            ->assertOk();

        $this->assertDatabaseHas('customers', ['id' => $customer->id, 'notes' => 'Mobil hali']);
    }

    public function test_cannot_resolve_an_already_resolved_conflict(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->putJson("/api/v1/customers/{$customer->id}", ['base_version' => 1, 'notes' => 'a'])->assertOk();
        $this->putJson("/api/v1/customers/{$customer->id}", ['base_version' => 1, 'notes' => 'b'])->assertConflict();

        $conflict = SyncConflict::firstOrFail();
        $this->postJson("/api/v1/sync-conflicts/{$conflict->id}/resolve", ['resolution' => 'SUNUCU_TUTULDU'])->assertOk();

        $this->postJson("/api/v1/sync-conflicts/{$conflict->id}/resolve", ['resolution' => 'MOBIL_TUTULDU'])
            ->assertUnprocessable();
    }

    public function test_a_non_owner_cannot_view_conflicts(): void
    {
        $user = User::factory()->create(['role' => 'VIEWER']);
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->getJson('/api/v1/sync-conflicts')->assertForbidden();
    }
}
