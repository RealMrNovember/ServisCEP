<?php

declare(strict_types=1);

namespace Tests\Feature\Subscription;

use App\Models\User;
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
        \App\Models\Setting::set(PaymentConfig::KEY_PROVIDER, PaymentConfig::PROVIDER_PAYTR);
        \App\Models\Setting::set(PaymentConfig::KEY_ENABLED, '1');

        $this->assertSame(PaymentConfig::MODE_TRANSFER, $this->kip());
    }

    public function test_switches_to_card_mode_when_fully_configured(): void
    {
        \App\Models\Setting::set(PaymentConfig::KEY_PROVIDER, PaymentConfig::PROVIDER_PAYTR);
        \App\Models\Setting::set(PaymentConfig::KEY_ENABLED, '1');
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
        \App\Models\Setting::set(PaymentConfig::KEY_PROVIDER, PaymentConfig::PROVIDER_PAYTR);
        \App\Models\Setting::set(PaymentConfig::KEY_ENABLED, '0');

        $this->assertSame(PaymentConfig::MODE_TRANSFER, $this->kip());
    }

    public function test_secrets_are_encrypted_at_rest(): void
    {
        // Merchant key/salt ile bir saldirgan sizin adiniza odeme istegi
        // imzalayabilir; veritabaninda duz metin durmamali.
        PaymentConfig::setSecret('payment.paytr.merchant_key', 'gizli-anahtar-42');

        $ham = \App\Models\Setting::query()->find('payment.paytr.merchant_key')?->value;

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
        \App\Models\Setting::set('payment_iban', 'TR00 0000 0000 0000 0000 0000 00');
        \App\Models\Setting::set(PaymentConfig::KEY_PROVIDER, PaymentConfig::PROVIDER_PAYTR);
        \App\Models\Setting::set(PaymentConfig::KEY_ENABLED, '1');
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
        $plan = \App\Models\Plan::create([
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
}
