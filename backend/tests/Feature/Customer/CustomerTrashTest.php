<?php

declare(strict_types=1);

namespace Tests\Feature\Customer;

use App\Models\Customer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Geri dönüşüm kutusu — bkz. ROADMAP.md § B10.
 */
class CustomerTrashTest extends TestCase
{
    use RefreshDatabase;

    public function test_deleted_customer_appears_in_trash_and_can_be_restored(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->deleteJson("/api/v1/customers/{$customer->id}")->assertNoContent();

        $this->getJson('/api/v1/customers/trash')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $customer->id);

        // Silinmiş müşteri normal listede görünmemeli.
        $this->getJson('/api/v1/customers')->assertOk()->assertJsonCount(0, 'data');

        $this->postJson("/api/v1/customers/{$customer->id}/restore")
            ->assertOk()
            ->assertJsonPath('data.id', $customer->id);

        $this->getJson('/api/v1/customers')->assertOk()->assertJsonCount(1, 'data');
        $this->assertDatabaseHas('customers', ['id' => $customer->id, 'deleted_at' => null]);
    }

    public function test_cannot_restore_another_companys_deleted_customer(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $foreignCustomer = Customer::factory()->create(['company_id' => $userB->company_id]);
        $foreignCustomer->delete();

        $this->withToken($userA->createToken('test')->plainTextToken)
            ->postJson("/api/v1/customers/{$foreignCustomer->id}/restore")
            ->assertNotFound();
    }
}
