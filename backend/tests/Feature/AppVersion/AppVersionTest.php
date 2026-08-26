<?php

declare(strict_types=1);

namespace Tests\Feature\AppVersion;

use App\Filament\Pages\AppVersionSettings;
use App\Http\Controllers\Api\V1\AppVersionController;
use App\Models\AdminUser;
use App\Models\Setting;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

/**
 * Yayındaki sürüm bilgisi.
 *
 * Uygulama güncelleme kontrolünü Play'e değil buraya soruyor: Play'in
 * kendi kontrolü, sürüm cihaza yayılana kadar "güncel" diyor ve bu saatler
 * sürebiliyordu. Kullanıcı yeni sürümden haberdar olmuyordu.
 */
class AppVersionTest extends TestCase
{
    use RefreshDatabase;

    public function test_uc_kimlik_dogrulamasi_istemez(): void
    {
        // Güncellemesi gereken bir kullanıcı, giriş yapamıyor da olabilir —
        // hatta güncelleme tam da bu yüzden gerekiyor olabilir.
        Setting::set(AppVersionController::KEY_VERSION, '0.7.2');
        Setting::set(AppVersionController::KEY_BUILD, '26');

        $this->getJson('/api/v1/app/version')
            ->assertOk()
            ->assertJsonPath('data.latest_version', '0.7.2')
            ->assertJsonPath('data.latest_build', 26);
    }

    public function test_ayar_yoksa_guvenli_varsayilanlar_doner(): void
    {
        // Sürüm hiç girilmemişse "güncelleme var" denmemeli: sürüm kodu 0,
        // hiçbir kurulumdan büyük olmaz.
        $this->getJson('/api/v1/app/version')
            ->assertOk()
            ->assertJsonPath('data.latest_build', 0)
            ->assertJsonPath('data.min_build', 0)
            ->assertJsonPath('data.store_url', AppVersionController::DEFAULT_STORE_URL);
    }

    public function test_panel_sayfasi_kaydediyor(): void
    {
        $admin = AdminUser::create([
            'full_name' => 'Süper Admin',
            'email' => 'admin@ornek.test',
            'password' => bcrypt('sifre1234'),
        ]);
        $this->actingAs($admin, 'admin');

        Livewire::test(AppVersionSettings::class)
            ->assertSuccessful()
            ->fillForm([
                'latest_version' => '0.8.0',
                'latest_build' => '30',
                'min_build' => '0',
                'notes' => 'Teklif formu yenilendi.',
                'store_url' => AppVersionController::DEFAULT_STORE_URL,
            ])
            ->call('save')
            ->assertHasNoErrors();

        $this->getJson('/api/v1/app/version')
            ->assertJsonPath('data.latest_build', 30)
            ->assertJsonPath('data.notes', 'Teklif formu yenilendi.');
    }

    /**
     * Jeton tanımlı değilse uç kapalıdır.
     *
     * Boş jeton "herkese açık" anlamına gelmemeli: yapılandırma unutulursa
     * uç, sunucudaki sürüm kaydını isteyen herkese yazdırabilirdi.
     */
    public function test_publish_endpoint_is_closed_when_no_token_is_configured(): void
    {
        config(['services.app_version.publish_token' => '']);

        $this->postJson('/api/v1/app/version', [
            'version' => '9.9.9',
            'build' => 999,
        ])->assertStatus(503);

        $this->assertNull(Setting::get(AppVersionController::KEY_VERSION));
    }

    public function test_publish_endpoint_rejects_a_wrong_token(): void
    {
        config(['services.app_version.publish_token' => 'dogru-jeton']);

        $this->withHeader('Authorization', 'Bearer yanlis-jeton')
            ->postJson('/api/v1/app/version', [
                'version' => '9.9.9',
                'build' => 999,
            ])->assertStatus(401);

        $this->assertNull(Setting::get(AppVersionController::KEY_VERSION));
    }

    /**
     * Asıl amaç: sürüm kaydı elle giriliyordu ve bir kez unutuldu.
     * 0.7.5 Play'e çıktı, sunucu "sürüm yok" dedi, kimseye güncelleme
     * bildirimi gitmedi.
     */
    public function test_ci_can_publish_the_released_version(): void
    {
        config(['services.app_version.publish_token' => 'dogru-jeton']);

        $this->withHeader('Authorization', 'Bearer dogru-jeton')
            ->postJson('/api/v1/app/version', [
                'version' => '0.7.7',
                'build' => 27,
                'notes' => 'Ödemelerim ekranı eklendi.',
            ])->assertOk()
            ->assertJsonPath('data.latest_version', '0.7.7');

        $this->assertSame('0.7.7', Setting::get(AppVersionController::KEY_VERSION));
        $this->assertSame('27', Setting::get(AppVersionController::KEY_BUILD));
        $this->assertSame('Ödemelerim ekranı eklendi.', Setting::get(AppVersionController::KEY_NOTES));
    }

    /**
     * Not gönderilmezse var olan not KORUNUR.
     *
     * Aksi halde notsuz bir yayın, bir önceki sürümün notunu silerdi ve
     * kullanıcı boş bir "yenilikler" ekranı görürdü.
     */
    public function test_publishing_without_notes_keeps_the_existing_notes(): void
    {
        config(['services.app_version.publish_token' => 'dogru-jeton']);
        Setting::set(AppVersionController::KEY_NOTES, 'Eski not');

        $this->withHeader('Authorization', 'Bearer dogru-jeton')
            ->postJson('/api/v1/app/version', [
                'version' => '0.7.8',
                'build' => 28,
            ])->assertOk();

        $this->assertSame('Eski not', Setting::get(AppVersionController::KEY_NOTES));
    }
}
