<?php

declare(strict_types=1);

namespace Tests\Feature\Customer;

use App\Models\Customer;
use App\Models\CustomerLedgerEntry;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Bkz. docs/15-cari-hesap.md — bakiye = SUM(DEBIT) - SUM(CREDIT).
 */
class CustomerLedgerTest extends TestCase
{
    use RefreshDatabase;

    public function test_lists_ledger_entries_with_derived_balance(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        CustomerLedgerEntry::factory()->create([
            'company_id' => $user->company_id, 'customer_id' => $customer->id, 'type' => 'DEBIT', 'amount_minor' => 100000,
        ]);
        CustomerLedgerEntry::factory()->create([
            'company_id' => $user->company_id, 'customer_id' => $customer->id, 'type' => 'CREDIT', 'amount_minor' => 30000,
        ]);

        $response = $this->getJson("/api/v1/customers/{$customer->id}/ledger");

        $response->assertOk()->assertJsonCount(2, 'data')->assertJsonPath('balance_minor', 70000);
    }

    public function test_records_a_manual_adjustment_with_required_description(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $response = $this->postJson("/api/v1/customers/{$customer->id}/ledger/adjustments", [
            'type' => 'DEBIT',
            'amount_minor' => 25000,
            'description' => 'Açılış bakiyesi',
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.type', 'DEBIT')
            ->assertJsonPath('data.reference_type', 'manual_adjustment')
            ->assertJsonPath('data.description', 'Açılış bakiyesi');
    }

    public function test_rejects_manual_adjustment_without_a_description(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->postJson("/api/v1/customers/{$customer->id}/ledger/adjustments", [
            'type' => 'DEBIT',
            'amount_minor' => 25000,
        ])->assertUnprocessable()->assertJsonValidationErrors('description');
    }

    public function test_cannot_view_another_companys_customer_ledger(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $foreignCustomer = Customer::factory()->create(['company_id' => $userB->company_id]);

        $this->withToken($userA->createToken('test')->plainTextToken)
            ->getJson("/api/v1/customers/{$foreignCustomer->id}/ledger")
            ->assertNotFound();
    }
}
