<?php

declare(strict_types=1);

namespace Tests\Feature\Subscription;

use App\Models\AdminUser;
use App\Models\Company;
use App\Models\PaymentRequest;
use App\Models\Plan;
use App\Models\Setting;
use App\Models\SubscriptionPayment;
use App\Models\User;
use App\Services\FcmService;
use App\Support\PaymentConfig;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Havale kipi ile kart kipi arasindaki gecis.
 *
 * Karar SUNUCUDA verilir: saglayici hazir degilken uygulamaya kart akisi
 * gosterilmemeli, yoksa kullanici calismayan bir odeme ekraninda takilir.
 */
class PaymentModeTest extends TestCase
{
    use RefreshDatabase;

    private function kip(): string
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        return $this->getJson('/api/v1/subscription')
            ->assertOk()
            ->json('data.payment_mode');
    }

    public function test_defaults_to_transfer_mode(): void
    {
        $this->assertSame(PaymentConfig::MODE_TRANSFER, $this->kip());
    }

    public function test_stays_in_transfer_mode_when_keys_are_missing(): void
    {
        // "Etkin" isareti tek basina yetmez. Eksik yapilandirmayla kart
        // kipine gecmek, kullaniciyi yarida kalan bir akisa sokar.
        Setting::set(PaymentConfig::KEY_PROVIDER, PaymentConfig::PROVIDER_PAYTR);
        Setting::set(PaymentConfig::KEY_ENABLED, '1');

        $this->assertSame(PaymentConfig::MODE_TRANSFER, $this->kip());
    }

    public function test_switches_to_card_mode_when_fully_configured(): void
    {
        Setting::set(PaymentConfig::KEY_PROVIDER, PaymentConfig::PROVIDER_PAYTR);
        Setting::set(PaymentConfig::KEY_ENABLED, '1');
        foreach (PaymentConfig::SECRET_KEYS as $anahtar) {
            PaymentConfig::setSecret($anahtar, 'deneme-deger-123456');
        }

        $this->assertSame(PaymentConfig::MODE_CARD, $this->kip());
    }

    public function test_disabling_returns_to_transfer_mode(): void
    {
        foreach (PaymentConfig::SECRET_KEYS as $anahtar) {
            PaymentConfig::setSecret($anahtar, 'deneme-deger-123456');
        }
        Setting::set(PaymentConfig::KEY_PROVIDER, PaymentConfig::PROVIDER_PAYTR);
        Setting::set(PaymentConfig::KEY_ENABLED, '0');

        $this->assertSame(PaymentConfig::MODE_TRANSFER, $this->kip());
    }

    public function test_secrets_are_encrypted_at_rest(): void
    {
        // Merchant key/salt ile bir saldirgan sizin adiniza odeme istegi
        // imzalayabilir; veritabaninda duz metin durmamali.
        PaymentConfig::setSecret('payment.paytr.merchant_key', 'gizli-anahtar-42');

        $ham = Setting::query()->find('payment.paytr.merchant_key')?->value;

        $this->assertNotNull($ham);
        $this->assertStringNotContainsString('gizli-anahtar-42', $ham);
        $this->assertSame('gizli-anahtar-42', PaymentConfig::secret('payment.paytr.merchant_key'));
    }

    public function test_masked_secret_hides_all_but_last_four(): void
    {
        PaymentConfig::setSecret('payment.paytr.merchant_id', 'ABCDEF123456');

        $maskeli = PaymentConfig::maskedSecret('payment.paytr.merchant_id');

        $this->assertNotNull($maskeli);
        $this->assertStringEndsWith('3456', $maskeli);
        $this->assertStringNotContainsString('ABCDEF', $maskeli);
    }

    public function test_transfer_info_is_sent_even_in_card_mode(): void
    {
        // Saglayici gecici olarak duserse kullanici yine de odeyebilmeli.
        Setting::set('payment_iban', 'TR00 0000 0000 0000 0000 0000 00');
        Setting::set(PaymentConfig::KEY_PROVIDER, PaymentConfig::PROVIDER_PAYTR);
        Setting::set(PaymentConfig::KEY_ENABLED, '1');
        foreach (PaymentConfig::SECRET_KEYS as $anahtar) {
            PaymentConfig::setSecret($anahtar, 'deneme-deger-123456');
        }

        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->getJson('/api/v1/subscription')
            ->assertOk()
            ->assertJsonPath('data.payment_mode', PaymentConfig::MODE_CARD)
            ->assertJsonPath('data.payment_info.iban', 'TR00 0000 0000 0000 0000 0000 00');
    }

    public function test_callback_rejects_unverified_hash(): void
    {
        // Dogrulanmamis bir bildirimle abonelik uzatilabilseydi, herkes
        // bize bir POST atarak kendine ucretsiz abonelik acabilirdi.
        $this->post('/api/v1/payments/paytr/callback', [
            'merchant_oid' => 'TCSAHTE123',
            'status' => 'success',
            'total_amount' => '100000',
            'hash' => 'uydurma-hash',
        ])->assertStatus(400);
    }

    public function test_checkout_is_unavailable_until_provider_is_ready(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $plan = Plan::create([
            'name' => 'Test Paketi',
            'slug' => 'test-paketi',
            'price_minor' => 100000,
            'price_yearly_minor' => 1000000,
            'duration_days' => 30,
        ]);

        $this->postJson('/api/v1/subscription/checkout', [
            'plan_id' => $plan->id,
            'duration' => 'MONTHLY',
        ])->assertStatus(503);
    }

    public function test_history_merges_card_and_transfer_payments(): void
    {
        // Kullanici icin ikisi ayni sey: "ne zaman, ne kadar odedim".
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $plan = Plan::create([
            'name' => 'Test Paketi',
            'slug' => 'test-gecmis',
            'price_minor' => 100000,
            'price_yearly_minor' => 1000000,
            'duration_days' => 30,
        ]);

        SubscriptionPayment::create([
            'company_id' => $user->company_id,
            'plan_id' => $plan->id,
            'amount_minor' => 100000,
            'currency' => 'TRY',
            'duration' => 'MONTHLY',
            'provider' => 'paytr',
            'provider_ref' => 'TCGECMIS1',
            'status' => 'PAID',
            'paid_at' => now(),
        ]);

        PaymentRequest::create([
            'company_id' => $user->company_id,
            'plan_id' => $plan->id,
            'claimed_amount_minor' => 50000,
            'status' => 'PENDING',
        ]);

        $yanit = $this->getJson('/api/v1/subscription/history')->assertOk();

        $this->assertCount(2, $yanit->json('data'));
        $turler = array_column($yanit->json('data'), 'kind');
        $this->assertContains('card', $turler);
        $this->assertContains('transfer', $turler);
    }

    public function test_history_is_scoped_to_own_company(): void
    {
        $baskasi = User::factory()->create();
        SubscriptionPayment::create([
            'company_id' => $baskasi->company_id,
            'amount_minor' => 100000,
            'currency' => 'TRY',
            'duration' => 'MONTHLY',
            'provider' => 'paytr',
            'provider_ref' => 'TCBASKASI1',
            'status' => 'PAID',
        ]);

        $ben = User::factory()->create();
        $this->withToken($ben->createToken('test')->plainTextToken);

        $this->getJson('/api/v1/subscription/history')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_rejection_notifies_the_customer(): void
    {
        // Kullanici havalesini yapmis ve cevap bekliyor. Reddedildigini
        // ogrenmesinin baska yolu yok; bildirim gonderilmezse parasinin
        // ne oldugunu bilmeden bekler.
        $sahte = new class extends FcmService
        {
            public array $gonderilen = [];

            public function __construct() {}

            public function sendToCompany(
                Company $company,
                string $title,
                string $body,
                array $data = [],
            ): int {
                $this->gonderilen[] = ['title' => $title, 'body' => $body, 'data' => $data];

                return 1;
            }
        };
        $this->app->instance(FcmService::class, $sahte);

        $user = User::factory()->create();
        $admin = AdminUser::create([
            'full_name' => 'Test Yonetici',
            'email' => 'yonetici-'.uniqid().'@teknikcep.test',
            'password' => 'gizli-parola-123',
        ]);

        $talep = PaymentRequest::create([
            'company_id' => $user->company_id,
            'claimed_amount_minor' => 50000,
            'status' => 'PENDING',
        ]);

        $talep->reject($admin, 'Tutar eksik gonderilmis.');

        $this->assertSame('REJECTED', $talep->fresh()->status);
        $this->assertCount(1, $sahte->gonderilen);
        $this->assertSame('Tutar eksik gonderilmis.', $sahte->gonderilen[0]['body']);
        $this->assertSame('payment_request_rejected', $sahte->gonderilen[0]['data']['type']);
    }

    public function test_orphan_callback_is_recorded_not_lost(): void
    {
        // Imzasi gecerli ama karsiligi olmayan bildirim: gercekten para
        // hareketi olmus demektir. Yalnizca gunluge yazmak yetmez,
        // gunlukler budaniyor; para hareketi budanmamali.
        Setting::set(PaymentConfig::KEY_PROVIDER, PaymentConfig::PROVIDER_PAYTR);
        Setting::set(PaymentConfig::KEY_ENABLED, '1');
        PaymentConfig::setSecret('payment.paytr.merchant_id', 'MID123');
        PaymentConfig::setSecret('payment.paytr.merchant_key', 'KEY123');
        PaymentConfig::setSecret('payment.paytr.merchant_salt', 'SALT123');

        $oid = 'TCYETIM0001';
        $imza = base64_encode(hash_hmac('sha256', $oid.'SALT123'.'success'.'250000', 'KEY123', true));

        $this->post('/api/v1/payments/paytr/callback', [
            'merchant_oid' => $oid,
            'status' => 'success',
            'total_amount' => '250000',
            'hash' => $imza,
        ])->assertOk()->assertSee('OK');

        $kayit = SubscriptionPayment::where('provider_ref', $oid)->first();

        $this->assertNotNull($kayit, 'Yetim odeme kayit altina alinmali');
        $this->assertSame(SubscriptionPayment::STATUS_ORPHAN, $kayit->status);
        $this->assertSame(250000, $kayit->amount_minor);
        $this->assertNull($kayit->company_id);
        $this->assertNotNull($kayit->provider_payload);
    }
}
