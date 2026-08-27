<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\User;
use App\Notifications\PasswordResetCode;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    /** Gönderilen bildirimden altı haneli kodu çıkarır. */
    private function kodOku(User $user): string
    {
        $kod = null;

        Notification::assertSentTo(
            $user,
            PasswordResetCode::class,
            function (PasswordResetCode $bildirim) use (&$kod, $user): bool {
                // toMail çıktısındaki kalın satır kodun kendisi.
                foreach ($bildirim->toMail($user)->introLines as $satir) {
                    if (preg_match('/^\*\*(\d{6})\*\*$/', $satir, $eslesme) === 1) {
                        $kod = $eslesme[1];
                    }
                }

                return true;
            }
        );

        $this->assertNotNull($kod, 'Bildirimde 6 haneli kod bulunamadı.');

        return (string) $kod;
    }

    public function test_kod_istegi_kullaniciya_e_posta_gonderir(): void
    {
        Notification::fake();
        $user = User::factory()->create(['email' => 'ahmet@ornek.com']);

        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'ahmet@ornek.com'])
            ->assertOk();

        Notification::assertSentTo($user, PasswordResetCode::class);
        $this->assertDatabaseHas('password_reset_tokens', ['email' => 'ahmet@ornek.com']);
    }

    /**
     * Kayıtlı olmayan e-posta da AYNI yanıtı almalı: farklı yanıt vermek,
     * bu ucu "bu e-posta sistemde var mı?" sorgusuna çevirir.
     */
    public function test_kayitli_olmayan_e_posta_ayni_yaniti_alir(): void
    {
        Notification::fake();
        $user = User::factory()->create(['email' => 'ahmet@ornek.com']);

        $varOlan = $this->postJson('/api/v1/auth/password/forgot', ['email' => 'ahmet@ornek.com']);
        $olmayan = $this->postJson('/api/v1/auth/password/forgot', ['email' => 'yok@ornek.com']);

        $this->assertSame($varOlan->status(), $olmayan->status());
        $this->assertSame(
            $varOlan->json('message'),
            $olmayan->json('message'),
        );
        Notification::assertSentToTimes($user, PasswordResetCode::class, 1);
    }

    public function test_dogru_kodla_parola_degisir_ve_giris_yapilir(): void
    {
        Notification::fake();
        $user = User::factory()->create([
            'email' => 'ahmet@ornek.com',
            'password' => 'eskiparola123',
        ]);

        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'ahmet@ornek.com'])->assertOk();
        $kod = $this->kodOku($user);

        $this->postJson('/api/v1/auth/password/reset', [
            'email' => 'ahmet@ornek.com',
            'code' => $kod,
            'password' => 'yeniparola456',
            'password_confirmation' => 'yeniparola456',
        ])->assertOk();

        $this->assertTrue(Hash::check('yeniparola456', $user->fresh()->password));

        $this->postJson('/api/v1/auth/login', [
            'email' => 'ahmet@ornek.com',
            'password' => 'yeniparola456',
        ])->assertOk();
    }

    public function test_kod_tek_kullanimliktir(): void
    {
        Notification::fake();
        $user = User::factory()->create(['email' => 'ahmet@ornek.com']);

        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'ahmet@ornek.com'])->assertOk();
        $kod = $this->kodOku($user);

        $govde = [
            'email' => 'ahmet@ornek.com',
            'code' => $kod,
            'password' => 'yeniparola456',
            'password_confirmation' => 'yeniparola456',
        ];

        $this->postJson('/api/v1/auth/password/reset', $govde)->assertOk();
        $this->postJson('/api/v1/auth/password/reset', $govde)
            ->assertStatus(422)
            ->assertJsonValidationErrors('code');
    }

    public function test_hatali_kod_reddedilir(): void
    {
        Notification::fake();
        User::factory()->create(['email' => 'ahmet@ornek.com']);

        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'ahmet@ornek.com'])->assertOk();

        $this->postJson('/api/v1/auth/password/reset', [
            'email' => 'ahmet@ornek.com',
            'code' => '000000',
            'password' => 'yeniparola456',
            'password_confirmation' => 'yeniparola456',
        ])->assertStatus(422)->assertJsonValidationErrors('code');
    }

    public function test_suresi_dolmus_kod_reddedilir(): void
    {
        Notification::fake();
        $user = User::factory()->create(['email' => 'ahmet@ornek.com']);

        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'ahmet@ornek.com'])->assertOk();
        $kod = $this->kodOku($user);

        // Kodun ömrü 15 dakika; 16 dakika öncesine çekiliyor.
        DB::table('password_reset_tokens')
            ->where('email', 'ahmet@ornek.com')
            ->update(['created_at' => now()->subMinutes(16)]);

        $this->postJson('/api/v1/auth/password/reset', [
            'email' => 'ahmet@ornek.com',
            'code' => $kod,
            'password' => 'yeniparola456',
            'password_confirmation' => 'yeniparola456',
        ])->assertStatus(422)->assertJsonValidationErrors('code');
    }

    /**
     * Sıfırlamanın sebebi çoğu zaman "hesabıma başkası erişmiş olabilir";
     * açık kalan bir jeton bırakmak sıfırlamayı anlamsız kılar.
     */
    public function test_sifirlama_tum_oturumlari_kapatir(): void
    {
        Notification::fake();
        $user = User::factory()->create(['email' => 'ahmet@ornek.com']);
        $eskiJeton = $user->createToken('mobile')->plainTextToken;

        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'ahmet@ornek.com'])->assertOk();
        $kod = $this->kodOku($user);

        $this->postJson('/api/v1/auth/password/reset', [
            'email' => 'ahmet@ornek.com',
            'code' => $kod,
            'password' => 'yeniparola456',
            'password_confirmation' => 'yeniparola456',
        ])->assertOk();

        $this->withToken($eskiJeton)->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    public function test_kisa_parola_reddedilir(): void
    {
        Notification::fake();
        $user = User::factory()->create(['email' => 'ahmet@ornek.com']);

        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'ahmet@ornek.com'])->assertOk();
        $kod = $this->kodOku($user);

        $this->postJson('/api/v1/auth/password/reset', [
            'email' => 'ahmet@ornek.com',
            'code' => $kod,
            'password' => 'kisa',
            'password_confirmation' => 'kisa',
        ])->assertStatus(422)->assertJsonValidationErrors('password');
    }
}
