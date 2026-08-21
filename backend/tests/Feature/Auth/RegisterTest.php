<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RegisterTest extends TestCase
{
    use RefreshDatabase;

    public function test_registers_a_new_company_and_owner_user_on_trial(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'company_name' => 'Ross Elektrik',
            'business_types' => 'Elektrik',
            'full_name' => 'Mike Ross',
            'email' => 'mike@example.com',
            'phone' => '5551234567',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.email', 'mike@example.com')
            ->assertJsonPath('data.role', 'OWNER')
            ->assertJsonPath('data.company.name', 'Ross Elektrik')
            ->assertJsonPath('data.company.business_types', 'Elektrik')
            ->assertJsonPath('data.company.is_active', true)
            ->assertJsonStructure(['data' => ['id', 'full_name', 'email', 'company'], 'token']);

        $this->assertDatabaseCount('companies', 1);
        $this->assertDatabaseHas('users', [
            'email' => 'mike@example.com',
            'role' => 'OWNER',
        ]);
    }

    public function test_can_log_in_immediately_after_registering_with_the_same_password(): void
    {
        // Bu test, parolanın kayıt sırasında yanlışlıkla iki kez
        // hash'lenmediğini kanıtlar (User::password cast'i zaten 'hashed'
        // — AuthService::register() elle Hash::make() ÇAĞIRMAMALI).
        $this->postJson('/api/v1/auth/register', [
            'company_name' => 'Ross Elektrik',
            'full_name' => 'Mike Ross',
            'email' => 'mike@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ])->assertCreated();

        $this->postJson('/api/v1/auth/login', [
            'email' => 'mike@example.com',
            'password' => 'password123',
        ])->assertOk();
    }

    public function test_rejects_duplicate_email(): void
    {
        User::factory()->create(['email' => 'mike@example.com']);

        $response = $this->postJson('/api/v1/auth/register', [
            'company_name' => 'Ross Elektrik',
            'business_types' => 'Elektrik',
            'full_name' => 'Mike Ross',
            'email' => 'mike@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_rejects_mismatched_password_confirmation(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'company_name' => 'Ross Elektrik',
            'business_types' => 'Elektrik',
            'full_name' => 'Mike Ross',
            'email' => 'mike@example.com',
            'password' => 'password123',
            'password_confirmation' => 'wrong',
        ]);

        $response->assertUnprocessable()->assertJsonValidationErrors('password');
    }

    public function test_rejects_missing_required_fields(): void
    {
        $response = $this->postJson('/api/v1/auth/register', []);

        $response->assertUnprocessable()->assertJsonValidationErrors([
            'company_name', 'full_name', 'email', 'password',
        ]);
    }
}
