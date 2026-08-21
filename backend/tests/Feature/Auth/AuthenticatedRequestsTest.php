<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthenticatedRequestsTest extends TestCase
{
    use RefreshDatabase;

    public function test_me_returns_the_authenticated_user_with_company(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withToken($token)->getJson('/api/v1/auth/me');

        $response->assertOk()
            ->assertJsonPath('data.id', $user->id)
            ->assertJsonPath('data.company.id', $user->company_id);
    }

    public function test_me_rejects_unauthenticated_requests(): void
    {
        $this->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    public function test_logout_revokes_the_current_token(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $this->withToken($token)->postJson('/api/v1/auth/logout')->assertOk();
        $this->assertDatabaseCount('personal_access_tokens', 0);

        // Sanctum'un RequestGuard'ı, aynı test metodu içindeki ardışık
        // simüle istekler arasında çözümlenmiş kullanıcıyı önbellekte tutar
        // (uygulama kodunda değil, yalnızca test ortamında görülen bilinen
        // bir Laravel davranışı). Token'ın gerçekten geçersiz kaldığını
        // doğrulamak için guard önbelleği elle temizlenir.
        $this->app['auth']->forgetGuards();

        $this->withToken($token)->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    public function test_each_users_token_only_reveals_their_own_company(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $tokenA = $userA->createToken('test')->plainTextToken;

        $response = $this->withToken($tokenA)->getJson('/api/v1/auth/me');

        $response->assertOk()->assertJsonPath('data.company.id', $userA->company_id);
        $this->assertNotSame($userB->company_id, $response->json('data.company.id'));
    }
}
