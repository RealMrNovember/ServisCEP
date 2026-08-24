<?php

declare(strict_types=1);

namespace Tests\Feature\Company;

use App\Models\Company;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CompanySettingsTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_sees_and_updates_own_company(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->getJson('/api/v1/company')
            ->assertOk()
            ->assertJsonPath('data.id', $user->company_id);

        $this->putJson('/api/v1/company', [
            'name' => 'Yeni Ünvan',
            'business_types' => 'Elektrik,Kamera',
            'iban' => 'TR330006100519786457841326',
        ])->assertOk()
            ->assertJsonPath('data.name', 'Yeni Ünvan')
            ->assertJsonPath('data.business_types', 'Elektrik,Kamera')
            ->assertJsonPath('data.iban', 'TR330006100519786457841326');

        $this->assertDatabaseHas('companies', [
            'id' => $user->company_id,
            'name' => 'Yeni Ünvan',
        ]);
    }

    public function test_non_owner_cannot_update(): void
    {
        $user = User::factory()->create(['role' => 'TECHNICIAN']);
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->putJson('/api/v1/company', ['name' => 'Olmaz'])->assertForbidden();
    }

    public function test_cannot_touch_another_companys_record(): void
    {
        $other = Company::factory()->create(['name' => 'Başka Firma']);
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        // Şirket oturumdan türetilir — istekte id göndermek bir şey değiştirmez.
        $this->putJson('/api/v1/company', [
            'id' => $other->id,
            'name' => 'Ele Geçirildi',
        ])->assertOk();

        $this->assertDatabaseHas('companies', ['id' => $other->id, 'name' => 'Başka Firma']);
    }

    public function test_validates_iban_length(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->putJson('/api/v1/company', ['iban' => str_repeat('X', 40)])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('iban');
    }
}
