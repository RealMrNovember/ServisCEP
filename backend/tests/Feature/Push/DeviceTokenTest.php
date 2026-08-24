<?php

declare(strict_types=1);

namespace Tests\Feature\Push;

use App\Models\DeviceToken;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DeviceTokenTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Aynı test içinde başka bir kullanıcıya geçmek için — Laravel'in auth
     * guard'ı ilk çözümlediği kullanıcıyı önbelleğinde tutar, yalnızca
     * Authorization başlığını değiştirmek yetmez.
     */
    private function actAsToken(string $token): void
    {
        $this->app['auth']->forgetGuards();
        $this->withToken($token);
    }

    public function test_registers_a_device_token(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->postJson('/api/v1/devices', ['token' => 'fcm-token-1'])
            ->assertCreated();

        $this->assertDatabaseHas('device_tokens', [
            'token' => 'fcm-token-1',
            'user_id' => $user->id,
            'company_id' => $user->company_id,
        ]);
    }

    public function test_re_registering_same_token_does_not_duplicate(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->postJson('/api/v1/devices', ['token' => 'fcm-token-1'])->assertCreated();
        $this->postJson('/api/v1/devices', ['token' => 'fcm-token-1'])->assertCreated();

        $this->assertSame(1, DeviceToken::where('token', 'fcm-token-1')->count());
    }

    public function test_token_moves_to_new_owner_when_another_user_signs_in_on_same_device(): void
    {
        $first = User::factory()->create();
        $this->withToken($first->createToken('test')->plainTextToken);
        $this->postJson('/api/v1/devices', ['token' => 'shared-device'])->assertCreated();

        // Aynı cihaza başka bir hesapla giriş yapıldı.
        $second = User::factory()->create();
        $this->actAsToken($second->createToken('test')->plainTextToken);
        $this->postJson('/api/v1/devices', ['token' => 'shared-device'])->assertCreated();

        $this->assertSame(1, DeviceToken::where('token', 'shared-device')->count());
        $this->assertDatabaseHas('device_tokens', [
            'token' => 'shared-device',
            'user_id' => $second->id,
        ]);
        // Eski kullanıcıya artık bildirim gitmemeli.
        $this->assertSame(0, DeviceToken::where('user_id', $first->id)->count());
    }

    public function test_unregisters_only_own_token(): void
    {
        $owner = User::factory()->create();
        $this->withToken($owner->createToken('test')->plainTextToken);
        $this->postJson('/api/v1/devices', ['token' => 'mine'])->assertCreated();

        $other = User::factory()->create();
        $this->actAsToken($other->createToken('test')->plainTextToken);
        // Başkasının token'ını silmeye çalışmak sessizce hiçbir şey yapmamalı.
        $this->deleteJson('/api/v1/devices', ['token' => 'mine'])->assertNoContent();
        $this->assertDatabaseHas('device_tokens', ['token' => 'mine']);

        $this->actAsToken($owner->createToken('test2')->plainTextToken);
        $this->deleteJson('/api/v1/devices', ['token' => 'mine'])->assertNoContent();
        $this->assertDatabaseMissing('device_tokens', ['token' => 'mine']);
    }

    public function test_requires_authentication(): void
    {
        $this->postJson('/api/v1/devices', ['token' => 'x'])->assertStatus(401);
    }

    public function test_device_registration_works_even_when_subscription_expired(): void
    {
        $user = User::factory()->create();
        \App\Models\Company::whereKey($user->company_id)->update([
            'subscription_expires_at' => now()->subDay(),
        ]);
        $this->withToken($user->createToken('test')->plainTextToken);

        // Süresi dolmuş kullanıcı da yenileme bildirimini alabilmeli.
        $this->postJson('/api/v1/devices', ['token' => 'expired-user-device'])
            ->assertCreated();
    }
}
