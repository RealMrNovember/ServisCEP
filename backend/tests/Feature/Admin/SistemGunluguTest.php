<?php

declare(strict_types=1);

namespace Tests\Feature\Admin;

use App\Filament\Resources\AppLogs\Pages\ListAppLogs;
use App\Filament\Widgets\BuyumeGrafigiWidget;
use App\Filament\Widgets\DikkatGerektirenlerWidget;
use App\Filament\Widgets\IsletmeOzetiWidget;
use App\Models\AdminUser;
use App\Models\AppLog;
use App\Models\Company;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Livewire\Livewire;
use Tests\TestCase;

/**
 * Sistem günlüğü ve panel göstergeleri.
 *
 * Bu testlerin varlık sebebi somut: panel ekranları yalnızca gerçekten
 * render edildiklerinde patlıyor (eksik alan, yanlış tip, hatalı ilişki).
 * Daha önce bir Filament aksiyonu tam da bu yüzden canlıda kırıldı ve
 * hiçbir test yakalamadı.
 */
class SistemGunluguTest extends TestCase
{
    use RefreshDatabase;

    private function adminOlarakGir(): AdminUser
    {
        $admin = AdminUser::create([
            'full_name' => 'Süper Admin',
            'email' => 'admin@ornek.test',
            'password' => bcrypt('sifre1234'),
        ]);
        $this->actingAs($admin, 'admin');

        return $admin;
    }

    private function gunlukKaydi(array $ozellikler = []): AppLog
    {
        return AppLog::create(array_merge([
            'id' => (string) Str::uuid(),
            'level' => 'error',
            'source' => AppLog::SOURCE_SERVER,
            'message' => 'Test hatası',
            'context' => ['reason' => 'ayrıntı'],
            'created_at' => now(),
        ], $ozellikler));
    }

    public function test_gunluk_listesi_render_ediliyor(): void
    {
        $this->adminOlarakGir();
        $this->gunlukKaydi();

        Livewire::test(ListAppLogs::class)
            ->assertSuccessful()
            ->assertCanSeeTableRecords(AppLog::all());
    }

    public function test_varsayilan_sekme_yalnizca_hatalari_gosterir(): void
    {
        $this->adminOlarakGir();

        $hata = $this->gunlukKaydi(['level' => 'error', 'message' => 'Kritik olay']);
        $bilgi = $this->gunlukKaydi(['level' => 'info', 'message' => 'Sıradan olay']);

        Livewire::test(ListAppLogs::class)
            ->assertSuccessful()
            ->assertCanSeeTableRecords([$hata])
            ->assertCanNotSeeTableRecords([$bilgi]);
    }

    public function test_mobil_sekmesi_yalnizca_mobil_kayitlari_gosterir(): void
    {
        $this->adminOlarakGir();

        $mobil = $this->gunlukKaydi([
            'source' => AppLog::SOURCE_MOBILE,
            'message' => 'Uygulama hatası',
        ]);
        $sunucu = $this->gunlukKaydi(['message' => 'Sunucu hatası']);

        Livewire::test(ListAppLogs::class)
            ->set('activeTab', 'mobil')
            ->assertSuccessful()
            ->assertCanSeeTableRecords([$mobil])
            ->assertCanNotSeeTableRecords([$sunucu]);
    }

    public function test_ayrinti_penceresi_acilabiliyor(): void
    {
        $this->adminOlarakGir();
        $kayit = $this->gunlukKaydi();

        Livewire::test(ListAppLogs::class)
            ->mountTableAction('ayrinti', $kayit)
            ->assertSuccessful();
    }

    public function test_panel_widgetlari_render_ediliyor(): void
    {
        $this->adminOlarakGir();
        Company::factory()->count(2)->create();
        $this->gunlukKaydi();

        Livewire::test(IsletmeOzetiWidget::class)->assertSuccessful();
        Livewire::test(BuyumeGrafigiWidget::class)->assertSuccessful();
        Livewire::test(DikkatGerektirenlerWidget::class)->assertSuccessful();
    }

    public function test_suresi_yaklasan_sirket_widgetta_gorunur(): void
    {
        $this->adminOlarakGir();

        $yaklasan = Company::factory()->create([
            'subscription_expires_at' => now()->addDays(3),
        ]);
        $uzak = Company::factory()->create([
            'subscription_expires_at' => now()->addDays(60),
        ]);

        Livewire::test(DikkatGerektirenlerWidget::class)
            ->assertCanSeeTableRecords([$yaklasan])
            ->assertCanNotSeeTableRecords([$uzak]);
    }

    public function test_laravel_log_kaydi_veritabanina_dusuyor(): void
    {
        // Kanal doğrudan çağrılır: varsayılan yığın test ortamında dosyaya
        // yazıyor, asıl doğrulamak istediğimiz ise handler'ın kendisi.
        Log::channel('database')->error('Deneme hatası', ['sebep' => 'test']);

        $kayit = AppLog::query()->where('message', 'Deneme hatası')->first();

        $this->assertNotNull($kayit, 'Log kaydı veritabanına yazılmadı');
        $this->assertSame(AppLog::SOURCE_SERVER, $kayit->source);
        $this->assertSame('error', $kayit->level);
        $this->assertSame('test', $kayit->context['sebep'] ?? null);
    }

    public function test_istisna_baglami_okunabilir_hale_getiriliyor(): void
    {
        Log::channel('database')->error('İstisna', [
            'exception' => new \RuntimeException('bir şey patladı'),
        ]);

        $kayit = AppLog::query()->where('message', 'İstisna')->firstOrFail();

        $this->assertSame(
            \RuntimeException::class,
            $kayit->context['exception']['class'] ?? null,
        );
        $this->assertSame(
            'bir şey patladı',
            $kayit->context['exception']['message'] ?? null,
        );
    }
}
