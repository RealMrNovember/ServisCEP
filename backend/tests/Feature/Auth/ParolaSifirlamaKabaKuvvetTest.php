<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * Parola sıfırlama kodunun kaba kuvvete karşı sınırları.
 *
 * NEDEN VAR: kod 6 haneli ve yanlış girildiğinde satır olduğu gibi
 * kalıyordu. 15 dakikalık pencere boyunca aynı e-posta için sınırsız
 * deneme yapılabiliyordu. Tek engel IP başına hız sınırıydı; o da tek
 * başına yeterli değil (IP değiştirilebilir, pencere beklenebilir).
 * Kodu bulan parolayı değiştirip tüm oturumları kapatabiliyor — yani
 * doğrudan hesap devri.
 */
class ParolaSifirlamaKabaKuvvetTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        // Hız sınırı BURADA devre dışı — ölçülen şey o değil.
        //
        // Rotanın kendi `throttle:5,10` sınırı var ve testteki bütün
        // istekler aynı IP'den geliyor; sayaç ölçmek istediğimiz
        // DENEME HAKKI'na sıra gelmeden 429 dönüyordu. Hız sınırının
        // kendisi ayrıca IstemciIpTest'te doğrulanıyor.
        $this->withoutMiddleware(ThrottleRequests::class);
    }

    private function kodIste(User $user): void
    {
        Notification::fake();
        $this->postJson('/api/v1/auth/password/forgot', ['email' => $user->email])
            ->assertSuccessful();
    }

    private function yanlisKodDene(User $user): TestResponse
    {
        return $this->postJson('/api/v1/auth/password/reset', [
            'email' => $user->email,
            'code' => '000000',
            'password' => 'YeniParola123!',
            'password_confirmation' => 'YeniParola123!',
        ]);
    }

    public function test_bes_yanlis_denemeden_sonra_kod_iptal_olur(): void
    {
        $user = User::factory()->create();
        $this->kodIste($user);

        // Kodu biliyoruz gibi davranmıyoruz: satırı okuyup DOĞRU kodu
        // sonradan deneyeceğiz, böylece "kod iptal oldu mu" ölçülebiliyor.
        for ($i = 1; $i <= 4; $i++) {
            $this->yanlisKodDene($user)->assertStatus(422);
            $this->assertNotNull(
                DB::table('password_reset_tokens')->where('email', $user->email)->first(),
                "$i. yanlış denemeden sonra kod hâlâ durmalı."
            );
        }

        // 5. yanlış deneme kodu iptal eder.
        $this->yanlisKodDene($user)->assertStatus(422);

        $this->assertNull(
            DB::table('password_reset_tokens')->where('email', $user->email)->first(),
            'Deneme hakkı bittiğinde kod silinmeli; aksi hâlde kaba kuvvet sürer.'
        );
    }

    public function test_yeni_kod_istemek_deneme_hakkini_sifirlar(): void
    {
        $user = User::factory()->create();
        $this->kodIste($user);

        $this->yanlisKodDene($user)->assertStatus(422);
        $this->yanlisKodDene($user)->assertStatus(422);

        $this->kodIste($user);

        $satir = DB::table('password_reset_tokens')->where('email', $user->email)->first();
        $this->assertSame(0, (int) $satir->attempts);
    }

    public function test_dogru_kod_hala_calisir(): void
    {
        // Sayaç eklenirken asıl akışın bozulmadığı da doğrulanmalı.
        $user = User::factory()->create();

        $kod = '123456';
        DB::table('password_reset_tokens')->updateOrInsert(
            ['email' => $user->email],
            ['token' => Hash::make($kod), 'created_at' => now(), 'attempts' => 0],
        );

        $this->postJson('/api/v1/auth/password/reset', [
            'email' => $user->email,
            'code' => $kod,
            'password' => 'YeniParola123!',
            'password_confirmation' => 'YeniParola123!',
        ])->assertSuccessful();

        $this->assertTrue(Hash::check('YeniParola123!', $user->refresh()->password));
    }

    public function test_yanlis_denemede_kalan_hak_sizdirilmaz(): void
    {
        // "2 hakkın kaldı" demek saldırgana bilgi vermek olur; mesaj her
        // durumda aynı kalmalı.
        $user = User::factory()->create();
        $this->kodIste($user);

        $ilk = $this->yanlisKodDene($user)->json('errors.code.0');
        $ikinci = $this->yanlisKodDene($user)->json('errors.code.0');

        $this->assertSame($ilk, $ikinci);
    }
}
