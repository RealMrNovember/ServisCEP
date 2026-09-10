<?php

declare(strict_types=1);

namespace Tests\Feature\Subscription;

use App\Models\Company;
use App\Models\Customer;
use App\Models\Plan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * Abonelik yaptırımının SINIRLARI.
 *
 * 2026-09-10'da sözleşme değişti: mobil veri uçlarındaki abonelik kapısı
 * kaldırıldı. Eskiden süresi dolmuş hesabın tüm veri uçları 402 ile
 * kesiliyordu ve sonucu şuydu — kullanıcı kaydını giriyor, kayıt cihazda
 * kuyruğa giriyor, sunucuya hiç ulaşmıyor. Canlıda 17 şirketin 9'unda
 * yaşandı; veri iki hafta boyunca yalnızca telefonlarda durdu.
 *
 * Ödemesi gecikmiş müşterinin verisini rehin almak tahsilat yöntemi
 * değil: telefon kaybolursa yedeklenmemiş kayıt da kaybolur.
 *
 * Ücretlendirme kapısı artık İSTEMCİDE: uygulama yeni kayıt
 * oluşturmayı engelliyor. Bu testler sunucunun ARTIK ENGELLEMEDİĞİNİ
 * doğruluyor — çünkü buradaki bir regresyon sessizce yedeklemeyi
 * durdurur ve kimse fark etmez.
 */
class SubscriptionEnforcementTest extends TestCase
{
    use RefreshDatabase;

    private function expiredUser(): User
    {
        $user = User::factory()->create();
        Company::whereKey($user->company_id)->update([
            'subscription_expires_at' => Carbon::now()->subDay(),
        ]);

        return $user->refresh();
    }

    public function test_suresi_dolmus_hesap_veri_okuyabilir(): void
    {
        $user = $this->expiredUser();
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->getJson('/api/v1/customers')->assertOk();
        $this->getJson('/api/v1/quotes')->assertOk();
        $this->getJson('/api/v1/jobs')->assertOk();
    }

    /**
     * Asıl mesele bu: cihazda biriken kayıt sunucuya ULAŞMALI.
     * Yedekleme hiçbir koşulda durmaz.
     */
    public function test_suresi_dolmus_hesap_veri_yazabilir(): void
    {
        $user = $this->expiredUser();
        $this->withToken($user->createToken('test')->plainTextToken);

        $yanit = $this->postJson('/api/v1/customers', [
            'id' => (string) Str::uuid(),
            'code' => 'MUS-001',
            'contact_name' => 'Gecikmis Odeme Musterisi',
            'type' => 'BIREYSEL',
        ]);

        $yanit->assertSuccessful();
        $this->assertDatabaseHas('customers', [
            'contact_name' => 'Gecikmis Odeme Musterisi',
            'company_id' => $user->company_id,
        ]);
    }

    public function test_suresi_dolmus_hesap_kimligini_ve_yenilemeyi_gorur(): void
    {
        $user = $this->expiredUser();
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->getJson('/api/v1/auth/me')->assertOk();
        $this->getJson('/api/v1/plans')->assertOk();

        // İstemcinin kapıyı kurabilmesi için bu alan ŞART: uygulama yeni
        // kayıt oluşturmayı buna bakarak engelliyor.
        $this->getJson('/api/v1/subscription')
            ->assertOk()
            ->assertJsonPath('data.has_active_subscription', false);
    }

    public function test_odeme_bildirimi_suresi_dolmusken_de_yapilabilir(): void
    {
        $user = $this->expiredUser();
        $this->withToken($user->createToken('test')->plainTextToken);

        $plan = Plan::create([
            'name' => 'Başlangıç',
            'slug' => 'baslangic',
            'price_minor' => 49900,
            'duration_days' => 30,
            'is_active' => true,
        ]);

        $this->postJson('/api/v1/subscription/payment-requests', [
            'plan_id' => $plan->id,
            // Zorunlu alan (StorePaymentRequestRequest). Eksikti ve test
            // 422 alıyordu; backend'in CI'ı olmadığı için kimse görmedi.
            'billing_period' => 'MONTHLY',
            'note' => 'Havale yaptım',
        ])->assertSuccessful();
    }

    public function test_aktif_hesap_etkilenmez(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->getJson('/api/v1/customers')->assertOk();
    }

    /**
     * Elle askıya alınmış hesapta da veri akışı sürüyor.
     *
     * Askıya alma bir tahsilat/denetim aracı; verinin sunucuya
     * ulaşmasını engellemesi için bir sebep yok ve engellerse aynı veri
     * kaybı riski geri gelir.
     */
    public function test_elle_askiya_alinmis_hesap_da_veri_gonderebilir(): void
    {
        $user = User::factory()->create();
        Company::whereKey($user->company_id)->update(['is_active' => false]);
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->getJson('/api/v1/customers')->assertOk();
    }

    public function test_app_panel_redirects_expired_company_to_subscription_page(): void
    {
        // Panelde kapı DURUYOR: orada veri doğrudan sunucuya yazılıyor,
        // yani engellemek "yedeklemeyi durdurmak" değil "yeni kayıt
        // girişini durdurmak" anlamına geliyor.
        $user = $this->expiredUser();

        $this->actingAs($user)
            ->get('/panel/customers')
            ->assertRedirect();
    }

    public function test_veri_ucu_hicbir_kosulda_402_donmez(): void
    {
        // Regresyon bekçisi: kapı geri konursa yedekleme sessizce durur
        // ve kimse fark etmez — canlıda iki hafta fark edilmedi.
        $user = $this->expiredUser();
        $this->withToken($user->createToken('test')->plainTextToken);

        foreach (['/api/v1/customers', '/api/v1/jobs', '/api/v1/quotes'] as $uc) {
            $this->getJson($uc)->assertStatus(200);
        }

        Customer::query()->delete();
    }
}
