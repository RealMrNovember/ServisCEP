<?php

declare(strict_types=1);

namespace Tests\Feature\Admin;

use App\Models\AdminUser;
use App\Models\Company;
use App\Models\User;
use App\Support\RolePermissions;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Yönetim panelinin kullanıcı üzerindeki yetkileri.
 *
 * NEDEN VAR: `/admin`'de kullanıcı silme, şirket değiştirme ve rol
 * değiştirme baştan beri vardı. `UserPolicy` yazılınca (2026-09-10,
 * kiracı panelindeki ayrıcalık yükseltmesini kapatmak için) Filament
 * artık bir politika BULUYOR ve `AdminUser` o politikadan geçemediği
 * için "Sil" düğmesi sessizce kayboldu. Yani bir güvenlik düzeltmesi,
 * fark edilmeden bir destek yeteneğini kaldırdı.
 *
 * Bu testler iki tarafı da tutuyor: yönetici işini yapabilmeli, kiracı
 * kullanıcısı ise başkasının şirketine karışamamalı.
 */
class AdminKullaniciYonetimiTest extends TestCase
{
    use RefreshDatabase;

    private function yonetici(): AdminUser
    {
        // AdminUser icin fabrika yok; AdminPanelRendersTest ile ayni kalip.
        return AdminUser::create([
            'full_name' => 'Super Admin',
            'email' => 'admin'.uniqid().'@ornek.test',
            'password' => bcrypt('sifre1234'),
        ]);
    }

    private function sirketKullanicisi(string $rol, ?Company $sirket = null): User
    {
        $user = User::factory()->create();
        $sirket ??= $user->company;

        User::whereKey($user->id)->update([
            'role' => $rol,
            'company_id' => $sirket->id,
        ]);

        return $user->refresh();
    }

    public function test_yonetici_kullanici_listesini_gorebilir(): void
    {
        $admin = $this->yonetici();
        $this->sirketKullanicisi(RolePermissions::OWNER);

        $this->assertTrue($admin->can('viewAny', User::class));
    }

    public function test_yonetici_kullaniciyi_silebilir(): void
    {
        // Asıl regresyon: destek, hatalı açılmış hesabı temizleyemiyordu.
        $admin = $this->yonetici();
        $sahip = $this->sirketKullanicisi(RolePermissions::OWNER);
        $teknisyen = $this->sirketKullanicisi(RolePermissions::TECHNICIAN, $sahip->company);

        $this->assertTrue($admin->can('delete', $teknisyen));
    }

    public function test_yonetici_tek_kullanicili_sirketin_sahibini_silebilir(): void
    {
        // Yanlışlıkla açılmış tek kişilik şirket — temizlenebilmeli.
        $admin = $this->yonetici();
        $yalnizSahip = $this->sirketKullanicisi(RolePermissions::OWNER);

        $this->assertTrue($admin->can('delete', $yalnizSahip));
    }

    public function test_yonetici_baskalari_varken_son_sahibi_silemez(): void
    {
        // Şirketi sahipsiz bırakmak: kalan personel hiçbir şey yönetemez.
        $admin = $this->yonetici();
        $sahip = $this->sirketKullanicisi(RolePermissions::OWNER);
        $this->sirketKullanicisi(RolePermissions::TECHNICIAN, $sahip->company);

        $this->assertFalse($admin->can('delete', $sahip));
    }

    public function test_yonetici_rolu_ve_sirketi_degistirebilir(): void
    {
        $admin = $this->yonetici();
        $kullanici = $this->sirketKullanicisi(RolePermissions::TECHNICIAN);

        $this->assertTrue($admin->can('update', $kullanici));
        $this->assertTrue($admin->can('changeRole', $kullanici));
    }

    public function test_yonetici_hesap_olusturamaz(): void
    {
        // Kullanıcı ya kendi kayıt olur ya da işletme sahibi ekler;
        // admin'in sessizce hesap açması sahipliği bulanıklaştırır.
        $admin = $this->yonetici();

        $this->assertFalse($admin->can('create', User::class));
    }

    public function test_kiraci_kullanicisi_yabanci_sirkete_karisamaz(): void
    {
        // Yönetici yetkisi genisletilirken kiracı tarafı gevsememeli.
        $sahip = $this->sirketKullanicisi(RolePermissions::OWNER);
        $yabanci = $this->sirketKullanicisi(RolePermissions::OWNER);

        $this->assertFalse($sahip->can('update', $yabanci));
        $this->assertFalse($sahip->can('delete', $yabanci));
    }
}
