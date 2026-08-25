<?php

declare(strict_types=1);

namespace Tests\Feature\Diagnostics;

use App\Models\AppLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Mobil tanılama ucu.
 *
 * En kritik davranış ilk testte: uç, KİMLİK DOĞRULAMASI OLMADAN çalışmak
 * zorunda. Bir cihazda kimlik doğrulamanın kendisi bozuldu ve kullanıcı
 * günlerce giriş yapamadı; hatayı gönderebileceği tek an giriş yapamadığı
 * andı. Bu testi kaldırmak, o körlüğü geri getirmek demektir.
 */
class DiagnosticsTest extends TestCase
{
    use RefreshDatabase;

    public function test_kimlik_dogrulamasi_olmadan_kayit_kabul_edilir(): void
    {
        $response = $this->postJson('/api/v1/diagnostics', [
            'message' => 'Giriş yapılamıyor',
            'detail' => 'SocketException: Failed host lookup',
            'screen' => 'login',
            'platform' => 'android',
            'app_version' => '0.7.1',
            'connectivity' => 'mobile',
        ]);

        $response->assertAccepted();

        $kayit = AppLog::query()->firstOrFail();
        $this->assertSame(AppLog::SOURCE_MOBILE, $kayit->source);
        $this->assertSame('Giriş yapılamıyor', $kayit->message);
        $this->assertSame('0.7.1', $kayit->app_version);
        $this->assertSame('mobile', $kayit->context['connectivity']);
        $this->assertNull($kayit->user_id);
    }

    public function test_oturum_acikken_kullanici_ve_sirket_iliskilendirilir(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->postJson('/api/v1/diagnostics', [
            'message' => 'Senkron başarısız',
        ])->assertAccepted();

        $kayit = AppLog::query()->firstOrFail();
        $this->assertSame($user->id, $kayit->user_id);
        $this->assertSame($user->company_id, $kayit->company_id);
    }

    public function test_mesaj_zorunlu(): void
    {
        $this->postJson('/api/v1/diagnostics', [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('message');
    }

    public function test_gecersiz_seviye_reddedilir(): void
    {
        $this->postJson('/api/v1/diagnostics', [
            'message' => 'test',
            'level' => 'sacmalik',
        ])->assertUnprocessable()->assertJsonValidationErrors('level');
    }

    public function test_asiri_uzun_ayrinti_reddedilir(): void
    {
        // Uç kimliksiz olduğu için sınırsız veri deposuna dönüşmemeli.
        $this->postJson('/api/v1/diagnostics', [
            'message' => 'test',
            'detail' => str_repeat('x', 5000),
        ])->assertUnprocessable()->assertJsonValidationErrors('detail');
    }

    public function test_basarisiz_istekler_gunluge_yazilir(): void
    {
        // Kimliksiz korumalı bir uç → 401. Ara katman bunu kaydetmeli;
        // "kullanıcı neden giremiyor" sorusunun cevabı çoğu zaman burada.
        $this->getJson('/api/v1/customers')->assertUnauthorized();

        $kayit = AppLog::query()
            ->where('source', AppLog::SOURCE_REQUEST)
            ->firstOrFail();

        $this->assertSame(401, $kayit->status);
        $this->assertSame('GET', $kayit->method);
        $this->assertSame('/api/v1/customers', $kayit->path);
        $this->assertNotNull($kayit->duration_ms);
    }

    public function test_dogrulama_hatasi_ve_sunucu_mesaji_kaydedilir(): void
    {
        // Kullanıcının neden içeri giremediği sorusunun cevabı çoğu zaman
        // sunucunun döndüğü mesajda; o mesaj kayda da geçmeli.
        $this->postJson('/api/v1/auth/login', [
            'email' => 'yok@ornek.test',
            'password' => 'yanlis',
        ])->assertUnprocessable();

        $kayit = AppLog::query()
            ->where('path', '/api/v1/auth/login')
            ->firstOrFail();

        $this->assertSame(422, $kayit->status);
        $this->assertNotNull($kayit->context['sunucu_mesaji'] ?? null);
    }

    public function test_basarili_istekler_gunlugu_sismez(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->getJson('/api/v1/customers')->assertOk();

        // Her 200'ü kaydetmek tabloyu kullanılamaz hâle getirirdi.
        $this->assertSame(
            0,
            AppLog::query()->where('source', AppLog::SOURCE_REQUEST)->count(),
        );
    }
}
