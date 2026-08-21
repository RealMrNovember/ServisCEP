<?php

declare(strict_types=1);

namespace Tests\Feature\Payment;

use App\Models\Customer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PaymentTest extends TestCase
{
    use RefreshDatabase;

    public function test_recording_a_payment_creates_a_matching_credit_ledger_entry(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $response = $this->postJson("/api/v1/customers/{$customer->id}/payments", [
            'amount_minor' => 50000,
            'method' => 'Nakit',
        ]);

        $response->assertCreated()->assertJsonPath('data.amount_minor', 50000);

        $this->assertDatabaseHas('customer_ledger_entries', [
            'customer_id' => $customer->id,
            'type' => 'CREDIT',
            'amount_minor' => 50000,
            'reference_type' => 'payment',
        ]);
    }

    public function test_lists_only_the_authenticated_companys_customer_payments(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->postJson("/api/v1/customers/{$customer->id}/payments", ['amount_minor' => 10000, 'method' => 'Nakit'])
            ->assertCreated();

        $this->getJson("/api/v1/customers/{$customer->id}/payments")
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_cannot_record_a_payment_for_another_companys_customer(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $foreignCustomer = Customer::factory()->create();

        $this->postJson("/api/v1/customers/{$foreignCustomer->id}/payments", ['amount_minor' => 10000, 'method' => 'Nakit'])
            ->assertNotFound();
    }
}
