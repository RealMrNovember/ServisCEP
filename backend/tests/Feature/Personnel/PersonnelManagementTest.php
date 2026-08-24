<?php

declare(strict_types=1);

namespace Tests\Feature\Personnel;

use App\Models\Company;
use App\Models\Plan;
use App\Models\User;
use App\Support\RolePermissions;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class PersonnelManagementTest extends TestCase
{
    use RefreshDatabase;

    private function owner(): User
    {
        $user = User::factory()->create(['role' => RolePermissions::OWNER]);
        $this->app['auth']->forgetGuards();
        $this->withToken($user->createToken('test')->plainTextToken);

        return $user;
    }

    public function test_owner_creates_personnel_who_can_then_log_in(): void
    {
        $owner = $this->owner();

        $this->postJson('/api/v1/personnel', [
            'full_name' => 'Ahmet Teknisyen',
            'email' => 'ahmet@ornek.test',
            'role' => RolePermissions::TECHNICIAN,
            'password' => 'GucluParola1',
        ])->assertCreated()->assertJsonPath('data.role', RolePermissions::TECHNICIAN);

        $created = User::where('email', 'ahmet@ornek.test')->first();
        $this->assertSame($owner->company_id, $created->company_id);

        // Parola TEK kez hash'lenmeli — çifte hash'leme regresyonu (bkz. B3).
        $this->assertTrue(Hash::check('GucluParola1', $created->password));

        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/auth/login', [
            'email' => 'ahmet@ornek.test',
            'password' => 'GucluParola1',
        ])->assertOk();
    }

    public function test_owner_role_cannot_be_assigned_through_this_endpoint(): void
    {
        $this->owner();

        $this->postJson('/api/v1/personnel', [
            'full_name' => 'Sahte Sahip',
            'email' => 'sahte@ornek.test',
            'role' => RolePermissions::OWNER,
            'password' => 'GucluParola1',
        ])->assertUnprocessable()->assertJsonValidationErrors('role');
    }

    public function test_plan_user_limit_is_enforced(): void
    {
        $owner = $this->owner();
        $plan = Plan::create([
            'name' => 'Başlangıç', 'slug' => 'baslangic',
            'price_minor' => 1, 'price_yearly_minor' => 1,
            'is_active' => true, 'sort_order' => 1, 'max_users' => 2,
        ]);
        Company::whereKey($owner->company_id)->update(['plan_id' => $plan->id]);

        // Sahip zaten 1 kullanıcı; ikinciyi ekleyebilmeli.
        $this->postJson('/api/v1/personnel', [
            'full_name' => 'Bir', 'email' => 'bir@ornek.test',
            'role' => RolePermissions::TECHNICIAN, 'password' => 'GucluParola1',
        ])->assertCreated();

        // Üçüncü limiti aşar.
        $this->postJson('/api/v1/personnel', [
            'full_name' => 'Iki', 'email' => 'iki@ornek.test',
            'role' => RolePermissions::TECHNICIAN, 'password' => 'GucluParola1',
        ])->assertUnprocessable();
    }

    public function test_owner_cannot_delete_or_demote_self(): void
    {
        $owner = $this->owner();

        $this->deleteJson("/api/v1/personnel/{$owner->id}")->assertUnprocessable();
        $this->putJson("/api/v1/personnel/{$owner->id}", [
            'role' => RolePermissions::VIEWER,
        ])->assertUnprocessable();
    }

    public function test_cannot_touch_personnel_from_another_company(): void
    {
        $this->owner();
        $stranger = User::factory()->create();

        $this->putJson("/api/v1/personnel/{$stranger->id}", ['full_name' => 'X'])->assertNotFound();
        $this->deleteJson("/api/v1/personnel/{$stranger->id}")->assertNotFound();
    }

    public function test_deleting_personnel_revokes_their_tokens(): void
    {
        $owner = $this->owner();
        $this->postJson('/api/v1/personnel', [
            'full_name' => 'Gidecek', 'email' => 'gidecek@ornek.test',
            'role' => RolePermissions::TECHNICIAN, 'password' => 'GucluParola1',
        ])->assertCreated();

        $staff = User::where('email', 'gidecek@ornek.test')->first();
        $staffToken = $staff->createToken('phone')->plainTextToken;

        $this->app['auth']->forgetGuards();
        $this->withToken($owner->createToken('again')->plainTextToken);
        $this->deleteJson("/api/v1/personnel/{$staff->id}")->assertNoContent();

        // Silinen personelin telefonundaki oturum artık geçersiz olmalı.
        $this->app['auth']->forgetGuards();
        $this->withToken($staffToken);
        $this->getJson('/api/v1/auth/me')->assertStatus(401);
    }

    public function test_non_owner_cannot_manage_personnel(): void
    {
        $user = User::factory()->create(['role' => RolePermissions::ADMIN]);
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->getJson('/api/v1/personnel')->assertForbidden();
        $this->postJson('/api/v1/personnel', [
            'full_name' => 'X', 'email' => 'x@ornek.test',
            'role' => RolePermissions::TECHNICIAN, 'password' => 'GucluParola1',
        ])->assertForbidden();
    }
}
