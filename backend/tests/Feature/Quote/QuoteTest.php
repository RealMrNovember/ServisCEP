<?php

declare(strict_types=1);

namespace Tests\Feature\Quote;

use App\Models\Customer;
use App\Models\Quote;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class QuoteTest extends TestCase
{
    use RefreshDatabase;

    public function test_creates_a_quote_with_items_and_calculates_total(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $response = $this->postJson('/api/v1/quotes', [
            'code' => 'TEK-0001',
            'customer_id' => $customer->id,
            'items' => [
                // 2 * 10000 = 20000 - 1000 iskonto = 19000, %20 KDV -> 22800
                ['description' => 'Kamera montajı', 'quantity' => 2, 'unit_price_minor' => 10000, 'discount_minor' => 1000, 'tax_rate' => 20],
                // 1 * 5000 = 5000, %0 KDV -> 5000
                ['description' => 'Kablo', 'quantity' => 1, 'unit_price_minor' => 5000, 'tax_rate' => 0],
            ],
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.code', 'TEK-0001')
            ->assertJsonPath('data.status', 'TASLAK')
            ->assertJsonPath('data.total_minor', 27800)
            ->assertJsonCount(2, 'data.items');

        $this->assertNotNull($response->json('data.created_at'));
    }

    public function test_rejects_quote_for_a_customer_belonging_to_another_company(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $foreignCustomer = Customer::factory()->create();

        $this->postJson('/api/v1/quotes', [
            'code' => 'TEK-0002',
            'customer_id' => $foreignCustomer->id,
            'items' => [['description' => 'Test', 'quantity' => 1, 'unit_price_minor' => 1000]],
        ])->assertUnprocessable()->assertJsonValidationErrors('customer_id');
    }

    public function test_updates_quote_status(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $quote = Quote::factory()->create(['company_id' => $user->company_id]);

        $this->putJson("/api/v1/quotes/{$quote->id}", ['status' => 'GONDERILDI'])
            ->assertOk()
            ->assertJsonPath('data.status', 'GONDERILDI');
    }

    public function test_cannot_access_another_companys_quote(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $foreignQuote = Quote::factory()->create(['company_id' => $userB->company_id]);

        $this->withToken($userA->createToken('test')->plainTextToken)
            ->getJson("/api/v1/quotes/{$foreignQuote->id}")
            ->assertNotFound();
    }
}
