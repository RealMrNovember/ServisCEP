<?php

declare(strict_types=1);

namespace Tests\Feature\Security;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * İstemci IP'si taklit edilemez.
 *
 * NEDEN VAR: `trustProxies(at: '*')` ile birlikte
 * `HEADER_X_FORWARDED_FOR` güveniliyordu. Symfony bu durumda XFF
 * zincirindeki bütün adresleri "güvenilir" sayıp eliyor ve geriye EN
 * SOLDAKİ — yani istemcinin kendi yazdığı — değer kalıyor. Cloudflare
 * gelen XFF'i silmiyor, sonuna ekliyor.
 *
 * Sonuç: her istekte farklı bir `X-Forwarded-For` göndererek TÜM hız
 * sınırları atlatılabiliyordu (giriş 10/dk, parola sıfırlama 5/10dk,
 * veri uçları 120/dk). AppLog'a yazılan IP ve ödeme sağlayıcısına giden
 * user_ip de sahteydi.
 *
 * Buna gerek de yoktu: nginx'te `real_ip_header CF-Connecting-IP`
 * Cloudflare aralıklarıyla kurulu ve PHP'ye zaten gerçek istemci IP'si
 * geliyor.
 */
class IstemciIpTest extends TestCase
{
    use RefreshDatabase;

    public function test_x_forwarded_for_istemci_ipsini_degistiremez(): void
    {
        $yanit = $this->withServerVariables([
            'REMOTE_ADDR' => '203.0.113.9', // nginx'in çözdüğü gerçek IP
        ])->call('GET', '/up', [], [], [], [
            'HTTP_X_FORWARDED_FOR' => '1.2.3.4',
        ]);

        $yanit->assertSuccessful();

        $this->assertSame(
            '203.0.113.9',
            request()->getClientIp(),
            'X-Forwarded-For istemci IP\'sini eziyor; hız sınırları atlatılabilir.'
        );
    }

    public function test_hiz_siniri_sahte_baslikla_sifirlanmaz(): void
    {
        // Aynı gerçek IP'den gelen istekler, XFF ne olursa olsun AYNI
        // kovaya düşmeli.
        $asiri = false;

        for ($i = 0; $i < 12; $i++) {
            $yanit = $this->withServerVariables(['REMOTE_ADDR' => '203.0.113.10'])
                ->call('POST', '/api/v1/auth/login', [
                    'email' => 'yok@ornek.test',
                    'password' => 'yanlis',
                ], [], [], [
                    'HTTP_ACCEPT' => 'application/json',
                    // Her istekte FARKLI: eskiden bu, sayacı sıfırlıyordu.
                    'HTTP_X_FORWARDED_FOR' => "10.0.0.$i",
                ]);

            if ($yanit->getStatusCode() === 429) {
                $asiri = true;
                break;
            }
        }

        $this->assertTrue(
            $asiri,
            'Rotating X-Forwarded-For ile hız sınırı atlatılabiliyor.'
        );
    }

    public function test_sema_basliklarina_guven_suruyor(): void
    {
        // PROTO/HOST/PORT'a güven KALKMAMALI: eksik olduğunda signed URL
        // doğrulaması şemayı yanlış çözüp her zaman 403 dönüyordu.
        $this->call('GET', '/up', [], [], [], [
            'HTTP_X_FORWARDED_PROTO' => 'https',
        ])->assertSuccessful();

        $this->assertSame('https', request()->getScheme());
    }
}
