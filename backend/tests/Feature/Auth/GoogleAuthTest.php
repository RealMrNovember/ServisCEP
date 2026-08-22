<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Socialite\Facades\Socialite;
use Laravel\Socialite\Two\User as SocialiteUser;
use Tests\TestCase;

/**
 * Bkz. ROADMAP.md — mobil "Google ile devam et" hiçbir zaman backend'e
 * bağlanmıyordu (tamamen yerel), gerçek kullanıcı testinde ortaya çıktı.
 * `Socialite::fake()` yalnızca `user()` (yönlendirme akışı) metodunu
 * kapsıyor, mobilin kullandığı `userFromToken()`'ı değil — bu yüzden
 * Facade doğrudan Mockery ile taklit ediliyor.
 */
class GoogleAuthTest extends TestCase
{
    use RefreshDatabase;

    private function fakeGoogleUser(string $id, string $email, string $name): void
    {
        $googleUser = SocialiteUser::fake(['id' => $id, 'email' => $email, 'name' => $name]);
        Socialite::shouldReceive('driver->userFromToken')->andReturn($googleUser);
    }

    public function test_google_login_fails_when_no_account_exists(): void
    {
        $this->fakeGoogleUser('g-1', 'yeni@example.com', 'Yeni Kullanıcı');

        $this->postJson('/api/v1/auth/google/login', ['id_token' => 'fake-token'])
            ->assertUnprocessable();
    }

    public function test_google_login_succeeds_for_an_existing_email_and_backfills_google_id(): void
    {
        $user = User::factory()->create(['email' => 'mevcut@example.com', 'google_id' => null]);
        $this->fakeGoogleUser('g-2', 'mevcut@example.com', 'Mevcut Kullanıcı');

        $this->postJson('/api/v1/auth/google/login', ['id_token' => 'fake-token'])
            ->assertOk()
            ->assertJsonPath('data.email', 'mevcut@example.com');

        $this->assertDatabaseHas('users', ['id' => $user->id, 'google_id' => 'g-2']);
    }

    public function test_google_register_creates_a_new_company_and_user(): void
    {
        $this->fakeGoogleUser('g-3', 'yenisirket@example.com', 'Şirket Sahibi');

        $response = $this->postJson('/api/v1/auth/google/register', [
            'id_token' => 'fake-token',
            'company_name' => 'Yeni Şirket',
            'business_types' => 'Elektrik',
        ]);

        $response->assertCreated()->assertJsonPath('data.email', 'yenisirket@example.com');
        $this->assertDatabaseHas('users', ['email' => 'yenisirket@example.com', 'google_id' => 'g-3', 'role' => 'OWNER']);
        $this->assertDatabaseHas('companies', ['name' => 'Yeni Şirket', 'business_types' => 'Elektrik']);
    }

    public function test_google_register_rejects_an_email_that_already_has_an_account(): void
    {
        User::factory()->create(['email' => 'zaten@example.com']);
        $this->fakeGoogleUser('g-4', 'zaten@example.com', 'Zaten Var');

        $this->postJson('/api/v1/auth/google/register', [
            'id_token' => 'fake-token',
            'company_name' => 'Tekrar Şirket',
        ])->assertUnprocessable();
    }
}
