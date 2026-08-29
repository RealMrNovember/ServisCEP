<?php

declare(strict_types=1);

namespace Tests\Feature\Admin;

use App\Filament\Widgets\SurumDagilimiWidget;
use App\Http\Controllers\Api\V1\AppVersionController;
use App\Models\AdminUser;
use App\Models\Setting;
use App\Models\User;
use Filament\Facades\Filament;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

/**
 * Kim uygulamayı kullanıyor ve hangi sürümde — panelin cevabı.
 *
 * Bu widget'ın varlık sebebi Play Console'un bu soruları
 * cevaplayamaması. Sayıların doğru olduğuna güvenilmesi gerekiyor:
 * yanlış bir "herkes güncel" rakamı, eski sürümde kalmış kullanıcıları
 * görünmez kılar ve tam da düzeltmeye çalıştığımız hatayı geri getirir.
 */
class SurumDagilimiWidgetTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $admin = AdminUser::create([
            'full_name' => 'Süper Admin',
            'email' => 'admin@ornek.test',
            'password' => bcrypt('sifre1234'),
        ]);
        $this->actingAs($admin, 'admin');
        Filament::setCurrentPanel('admin');

        // Anahtarlar AppVersionController'ın sabitlerinden alınıyor:
        // elle yazılan bir dize sessizce eşleşmiyor ve widget "sürüm
        // bilinmiyor" durumuna düşüyordu.
        Setting::set(AppVersionController::KEY_VERSION, '0.8.3');
        Setting::set(AppVersionController::KEY_BUILD, '36');
    }

    public function test_widget_render_olur(): void
    {
        User::factory()->create();

        Livewire::test(SurumDagilimiWidget::class)->assertSuccessful();
    }

    public function test_hic_acmamis_kullanici_acan_sayisina_girmez(): void
    {
        // Kurup hiç açmamış: last_seen_at null. Play bu ayrımı hiç
        // göstermiyor, bizim göstermemiz gerekiyor.
        User::factory()->create(['last_seen_at' => null]);
        User::factory()->create(['last_seen_at' => now()]);

        Livewire::test(SurumDagilimiWidget::class)
            ->assertSuccessful()
            ->assertSee('2 kayıtlı kullanıcının');
    }

    public function test_eski_surumde_kalanlar_sayilir(): void
    {
        User::factory()->create([
            'app_build' => 36,
            'app_version' => '0.8.3',
            'last_seen_at' => now(),
        ]);
        User::factory()->create([
            'app_build' => 14,
            'app_version' => '0.2.12',
            'last_seen_at' => now(),
        ]);

        Livewire::test(SurumDagilimiWidget::class)
            ->assertSuccessful()
            ->assertSee('1 kişi eski sürümde');
    }

    public function test_herkes_guncelse_uyari_cikmaz(): void
    {
        User::factory()->create([
            'app_build' => 36,
            'app_version' => '0.8.3',
            'last_seen_at' => now(),
        ]);

        Livewire::test(SurumDagilimiWidget::class)
            ->assertSuccessful()
            ->assertSee('Herkes 0.8.3 sürümünde');
    }

    public function test_surum_dagilimi_kisi_sayisiyla_listelenir(): void
    {
        User::factory()->count(2)->create([
            'app_build' => 36,
            'app_version' => '0.8.3',
            'last_seen_at' => now(),
        ]);
        User::factory()->create([
            'app_build' => 14,
            'app_version' => '0.2.12',
            'last_seen_at' => now(),
        ]);

        Livewire::test(SurumDagilimiWidget::class)
            ->assertSuccessful()
            ->assertSee('0.8.3 (36): 2 kişi')
            ->assertSee('0.2.12 (14): 1 kişi');
    }
}
