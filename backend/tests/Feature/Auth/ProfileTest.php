<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\Company;
use App\Models\User;
use App\Support\RolePermissions;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class ProfileTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_updates_own_name_and_phone(): void
    {
        $user = User::factory()->create(['full_name' => 'Eski Ad']);
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->putJson('/api/v1/auth/profile', [
            'full_name' => 'Yeni Ad',
            'phone' => '05001112233',
        ])->assertOk()->assertJsonPath('data.full_name', 'Yeni Ad');

        $this->assertSame('05001112233', $user->refresh()->phone);
    }

    public function test_role_and_email_cannot_be_changed_through_profile(): void
    {
        $user = User::factory()->create([
            'role' => RolePermissions::TECHNICIAN,
            'email' => 'teknisyen@ornek.test',
        ]);
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->putJson('/api/v1/auth/profile', [
            'full_name' => 'Yeni Ad',
            'role' => RolePermissions::OWNER,
            'email' => 'sahip@ornek.test',
        ])->assertOk();

        $user->refresh();
        // Kullanıcı kendini yükseltemez, e-postasını da buradan değiştiremez.
        $this->assertSame(RolePermissions::TECHNICIAN, $user->role);
        $this->assertSame('teknisyen@ornek.test', $user->email);
    }

    public function test_password_change_requires_the_current_password(): void
    {
        $user = User::factory()->create(['password' => Hash::make('EskiParola1')]);
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->putJson('/api/v1/auth/password', [
            'current_password' => 'YanlisParola',
            'password' => 'YeniParola1',
            'password_confirmation' => 'YeniParola1',
        ])->assertUnprocessable()->assertJsonValidationErrors('current_password');

        $this->assertTrue(Hash::check('EskiParola1', $user->refresh()->password));
    }

    public function test_password_change_works_and_is_hashed_once(): void
    {
        $user = User::factory()->create(['password' => Hash::make('EskiParola1')]);
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->putJson('/api/v1/auth/password', [
            'current_password' => 'EskiParola1',
            'password' => 'YeniParola1',
            'password_confirmation' => 'YeniParola1',
        ])->assertOk();

        // Çifte hash'leme regresyonu: yeni parolayla giriş yapılabilmeli.
        $this->assertTrue(Hash::check('YeniParola1', $user->refresh()->password));

        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'YeniParola1',
        ])->assertOk();
    }

    public function test_password_change_revokes_other_devices_but_keeps_current(): void
    {
        $user = User::factory()->create(['password' => Hash::make('EskiParola1')]);
        $otherDevice = $user->createToken('eski-telefon')->plainTextToken;
        $current = $user->createToken('bu-telefon')->plainTextToken;

        $this->withToken($current);
        $this->putJson('/api/v1/auth/password', [
            'current_password' => 'EskiParola1',
            'password' => 'YeniParola1',
            'password_confirmation' => 'YeniParola1',
        ])->assertOk();

        // Mevcut cihaz açık kalmalı.
        $this->app['auth']->forgetGuards();
        $this->withToken($current);
        $this->getJson('/api/v1/auth/me')->assertOk();

        // Diğer cihaz düşmeli — aksi halde parola değiştirmenin anlamı olmaz.
        $this->app['auth']->forgetGuards();
        $this->withToken($otherDevice);
        $this->getJson('/api/v1/auth/me')->assertStatus(401);
    }

    public function test_profile_stays_reachable_when_subscription_expired(): void
    {
        $user = User::factory()->create();
        Company::whereKey($user->company_id)->update([
            'subscription_expires_at' => now()->subDay(),
        ]);
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->putJson('/api/v1/auth/profile', ['full_name' => 'Hâlâ Düzenlenebilir'])
            ->assertOk();
    }
}
