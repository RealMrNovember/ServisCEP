<?php

declare(strict_types=1);

namespace Tests\Feature\Panel;

use App\Models\Company;
use App\Models\ExpenseEntry;
use App\Models\IncomeEntry;
use App\Models\Job;
use App\Models\User;
use App\Support\RolePermissions;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Gate;
use Tests\TestCase;

/**
 * `/panel` (müşteri paneli) yetki sınırları.
 *
 * NEDEN VAR: Filament, bir model için policy bulamadığında VARSAYILAN
 * OLARAK İZİN VERİYOR. `strictAuthorization()` da açık değil. Bu iki
 * şeyin bileşimi, "politika yazmayı unutmak" ile "herkese açmak" arasına
 * hiçbir fark koymuyordu — ve unutulan her model sessizce herkese
 * açılıyordu.
 *
 * Canlıda şu delikler vardı:
 *  - User (Personel): hiç policy yok → TECHNICIAN kendine OWNER hesabı
 *    açıp işletme sahibinin parolasını değiştirebiliyordu.
 *  - Product, Warranty: hiç policy yok → VIEWER bile silebiliyordu.
 *  - IncomeEntry/ExpenseEntry: update/delete yok → TECHNICIAN menüde
 *    göremese de doğrudan URL ile finansal kaydı değiştirebiliyordu,
 *    oysa rol matrisinin ilk kuralı "teknisyen finansal veriyi göremez".
 *  - Job/Quote/Proforma: delete yok → her rol silebiliyordu.
 *
 * Buradaki testler açığı değil, KURALI koruyor: yeni bir kaynak eklenip
 * politikası yazılmazsa aşağıdaki son test bunu yakalar.
 */
class PanelYetkiTest extends TestCase
{
    use RefreshDatabase;

    private function kullanici(string $rol, ?Company $sirket = null): User
    {
        $user = User::factory()->create();
        $sirket ??= $user->company;

        User::whereKey($user->id)->update([
            'role' => $rol,
            'company_id' => $sirket->id,
        ]);

        return $user->refresh();
    }

    // ── Personel (B1: ayrıcalık yükseltme) ──────────────────────────

    public function test_teknisyen_personel_ekranini_goremez(): void
    {
        $teknisyen = $this->kullanici(RolePermissions::TECHNICIAN);

        $this->assertFalse($teknisyen->can('viewAny', User::class));
        $this->assertFalse($teknisyen->can('create', User::class));
    }

    public function test_teknisyen_isletme_sahibini_duzenleyemez(): void
    {
        $sahip = $this->kullanici(RolePermissions::OWNER);
        $teknisyen = $this->kullanici(RolePermissions::TECHNICIAN, $sahip->company);

        // Asıl senaryo buydu: sahibin parolasını panelden değiştirmek.
        $this->assertFalse($teknisyen->can('update', $sahip));
        $this->assertFalse($teknisyen->can('delete', $sahip));
    }

    public function test_sahip_kendi_rolunu_degistiremez(): void
    {
        $sahip = $this->kullanici(RolePermissions::OWNER);

        // Kendi rolünü düşürmek/yükseltmek yetki yükseltmenin en kısa yolu.
        $this->assertFalse($sahip->can('changeRole', $sahip));
    }

    public function test_son_isletme_sahibi_silinemez(): void
    {
        $sahip = $this->kullanici(RolePermissions::OWNER);
        $ikinciSahip = $this->kullanici(RolePermissions::OWNER, $sahip->company);

        // Tek sahip kaldığında silinemez: şirket sahipsiz kalırsa kimse
        // personel yönetemez ve hesap kurtarılamaz.
        $this->assertTrue($sahip->can('delete', $ikinciSahip));

        User::whereKey($ikinciSahip->id)->update(['role' => RolePermissions::ADMIN]);
        $this->assertFalse($sahip->refresh()->can('delete', $sahip));
    }

    public function test_baska_sirketin_personeline_dokunulamaz(): void
    {
        $sahip = $this->kullanici(RolePermissions::OWNER);
        $yabanci = $this->kullanici(RolePermissions::TECHNICIAN);

        $this->assertNotSame($sahip->company_id, $yabanci->company_id);
        $this->assertFalse($sahip->can('view', $yabanci));
        $this->assertFalse($sahip->can('update', $yabanci));
    }

    public function test_sahip_personel_yonetebilir(): void
    {
        $sahip = $this->kullanici(RolePermissions::OWNER);
        $teknisyen = $this->kullanici(RolePermissions::TECHNICIAN, $sahip->company);

        $this->assertTrue($sahip->can('viewAny', User::class));
        $this->assertTrue($sahip->can('create', User::class));
        $this->assertTrue($sahip->can('update', $teknisyen));
        $this->assertTrue($sahip->can('delete', $teknisyen));
        $this->assertTrue($sahip->can('changeRole', $teknisyen));
    }

    public function test_owner_atanabilir_roller_arasinda_degil(): void
    {
        // Panel formu bu listeden besleniyor; OWNER burada olmamalı.
        $this->assertNotContains(RolePermissions::OWNER, RolePermissions::ASSIGNABLE);
    }

    // ── Finans (rol matrisinin ilk kuralı) ──────────────────────────

    public function test_teknisyen_finansal_kaydi_duzenleyemez(): void
    {
        $sahip = $this->kullanici(RolePermissions::OWNER);
        $teknisyen = $this->kullanici(RolePermissions::TECHNICIAN, $sahip->company);

        $gelir = IncomeEntry::factory()->create(['company_id' => $sahip->company_id]);
        $gider = ExpenseEntry::factory()->create(['company_id' => $sahip->company_id]);

        // Menüde gizli olması yetmez: doğrudan URL ile de girilemesin.
        $this->assertFalse($teknisyen->can('view', $gelir));
        $this->assertFalse($teknisyen->can('update', $gelir));
        $this->assertFalse($teknisyen->can('delete', $gelir));
        $this->assertFalse($teknisyen->can('update', $gider));
        $this->assertFalse($teknisyen->can('delete', $gider));
    }

    // ── Silme (VIEWER her şeyi silebiliyordu) ───────────────────────

    public function test_salt_okunur_kullanici_hicbir_seyi_silemez(): void
    {
        $sahip = $this->kullanici(RolePermissions::OWNER);
        $izleyici = $this->kullanici(RolePermissions::VIEWER, $sahip->company);

        $is = Job::factory()->create(['company_id' => $sahip->company_id]);

        $this->assertFalse($izleyici->can('delete', $is));
        $this->assertFalse($izleyici->can('update', $is));
    }

    // ── Bekçi: politikası olmayan kaynak kalmasın ───────────────────

    public function test_panel_kaynaklarinin_hepsinin_politikasi_var(): void
    {
        // Filament, policy yoksa İZİN VERİYOR. Yeni bir kaynak eklenip
        // politikası unutulursa bu test kırılır — sessizce herkese
        // açılmasındansa CI'da patlaması iyidir.
        $gerekliMetotlar = ['viewAny', 'view', 'create', 'update', 'delete'];
        $eksikler = [];

        foreach (glob(app_path('Filament/App/Resources/*/*Resource.php')) as $dosya) {
            $sinif = 'App\\Filament\\App\\Resources\\'
                .basename(dirname($dosya)).'\\'
                .basename($dosya, '.php');

            if (! class_exists($sinif)) {
                continue;
            }

            $model = $sinif::getModel();
            $policy = Gate::getPolicyFor($model);

            if ($policy === null) {
                $eksikler[] = "$model: politika YOK";

                continue;
            }

            foreach ($gerekliMetotlar as $metot) {
                if (! method_exists($policy, $metot)) {
                    $eksikler[] = $model.'::'.$metot.' tanımsız';
                }
            }
        }

        $this->assertSame(
            [],
            $eksikler,
            "Politikası eksik panel kaynağı var; Filament bunlara varsayılan olarak İZİN VERİR:\n"
            .implode("\n", $eksikler)
        );
    }
}
