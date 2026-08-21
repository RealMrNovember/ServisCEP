<?php

declare(strict_types=1);

namespace Tests\Feature\Customer;

use App\Models\Customer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Şirket bazlı veri izolasyonunun (bkz. Concerns/BelongsToCompany.php)
 * gerçek bir kaynak üzerinden kanıtlanması — proje ilkesi: "şirket
 * izolasyonu hiçbir koşulda bozulamaz" (bkz. docs/11).
 */
class CustomerIsolationTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_company_cannot_list_another_companys_customers(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();

        Customer::factory()->count(2)->create(['company_id' => $userA->company_id]);
        Customer::factory()->count(5)->create(['company_id' => $userB->company_id]);

        $tokenA = $userA->createToken('test')->plainTextToken;

        $this->withToken($tokenA)->getJson('/api/v1/customers')
            ->assertOk()
            ->assertJsonCount(2, 'data');
    }

    public function test_a_company_cannot_view_another_companys_customer_by_id(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $foreignCustomer = Customer::factory()->create(['company_id' => $userB->company_id]);

        $tokenA = $userA->createToken('test')->plainTextToken;

        $this->withToken($tokenA)->getJson("/api/v1/customers/{$foreignCustomer->id}")
            ->assertNotFound();
    }

    public function test_a_company_cannot_update_another_companys_customer(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $foreignCustomer = Customer::factory()->create(['company_id' => $userB->company_id]);

        $tokenA = $userA->createToken('test')->plainTextToken;

        $this->withToken($tokenA)
            ->putJson("/api/v1/customers/{$foreignCustomer->id}", ['phone' => '5550000000'])
            ->assertNotFound();

        $this->assertDatabaseHas('customers', [
            'id' => $foreignCustomer->id,
            'phone' => $foreignCustomer->phone,
        ]);
    }

    public function test_a_company_cannot_delete_another_companys_customer(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $foreignCustomer = Customer::factory()->create(['company_id' => $userB->company_id]);

        $tokenA = $userA->createToken('test')->plainTextToken;

        $this->withToken($tokenA)->deleteJson("/api/v1/customers/{$foreignCustomer->id}")
            ->assertNotFound();

        $this->assertDatabaseHas('customers', ['id' => $foreignCustomer->id, 'deleted_at' => null]);
    }
}
