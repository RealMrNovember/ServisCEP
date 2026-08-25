<?php

declare(strict_types=1);

namespace Tests\Feature\Admin;

use App\Models\Customer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Kullanicinin hangi surumu kullandiginin kaydedilmesi.
 *
 * Destek tarafi "hangi surumu kullaniyorsunuz" sorusunu sormadan
 * cevaplayabilsin diye. Sunucu bu basliklari zaten okuyordu ama mobil
 * uygulama HIC gondermiyordu; uretimde 21 gunluk satirinin 21'inde de
 * surum sutunu bostu.
 */
class ClientVersionTrackingTest extends TestCase
{
    use RefreshDatabase;

    private function tokenAl(User $user): void
    {
        $this->withToken($user->createToken('test')->plainTextToken);
    }

    public function test_records_client_version_from_request_headers(): void
    {
        $user = User::factory()->create();
        $this->tokenAl($user);
        Customer::factory()->create(['company_id' => $user->company_id]);

        $this->withHeaders([
            'X-App-Version' => '0.7.5',
            'X-App-Build' => '29',
            'X-Platform' => 'android',
            'X-Device-Model' => 'Android 14',
        ])->getJson('/api/v1/customers')->assertOk();

        $user->refresh();

        $this->assertSame('0.7.5', $user->app_version);
        $this->assertSame(29, $user->app_build);
        $this->assertSame('android', $user->client_platform);
        $this->assertSame('Android 14', $user->device_info);
        $this->assertNotNull($user->last_seen_at);
    }

    public function test_records_version_on_successful_requests_too(): void
    {
        // Gunluk yalnizca hatali ve yavas isteklerde yaziliyor. Surum
        // bilgisi ise BASARILI isteklerden ogreniliyor; kunye kaydinin
        // gunluk kosullarindan bagimsiz olmasinin sebebi bu.
        $user = User::factory()->create();
        $this->tokenAl($user);

        $this->withHeaders(['X-App-Version' => '0.7.5', 'X-App-Build' => '29'])
            ->getJson('/api/v1/app/version')
            ->assertOk();

        // /app/version kimlik istemiyor; kunye icin kimlikli bir uc gerekir.
        Customer::factory()->create(['company_id' => $user->company_id]);
        $this->withHeaders(['X-App-Version' => '0.7.5', 'X-App-Build' => '29'])
            ->getJson('/api/v1/customers')
            ->assertOk();

        $this->assertSame('0.7.5', $user->fresh()->app_version);
    }

    public function test_missing_headers_leave_previous_value_untouched(): void
    {
        // Baslik gondermeyen eski bir surum, daha once kaydedilmis
        // bilgiyi SILMEMELI; aksi halde tek bir eski istemci istegi
        // destek tarafini yeniden kor birakirdi.
        $user = User::factory()->create();
        $user->forceFill(['app_version' => '0.7.4', 'app_build' => 28])->saveQuietly();

        $this->tokenAl($user);
        Customer::factory()->create(['company_id' => $user->company_id]);

        $this->getJson('/api/v1/customers')->assertOk();

        $user->refresh();
        $this->assertSame('0.7.4', $user->app_version);
        $this->assertSame(28, $user->app_build);
    }

    public function test_updates_when_user_upgrades(): void
    {
        $user = User::factory()->create();
        $user->forceFill([
            'app_version' => '0.7.4',
            'app_build' => 28,
            'last_seen_at' => now(),
        ])->saveQuietly();

        $this->tokenAl($user);
        Customer::factory()->create(['company_id' => $user->company_id]);

        $this->withHeaders(['X-App-Version' => '0.7.5', 'X-App-Build' => '29'])
            ->getJson('/api/v1/customers')
            ->assertOk();

        $user->refresh();
        $this->assertSame('0.7.5', $user->app_version);
        $this->assertSame(29, $user->app_build);
    }
}
