<?php

declare(strict_types=1);

namespace Tests\Feature\Proforma;

use App\Models\Customer;
use App\Models\Proforma;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ProformaTest extends TestCase
{
    use RefreshDatabase;

    public function test_creates_a_proforma_with_items_and_calculates_total(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $response = $this->postJson('/api/v1/proformas', [
            'code' => 'PRO-0001',
            'customer_id' => $customer->id,
            'valid_until' => now()->addDays(15)->toDateString(),
            'items' => [
                ['description' => 'Bakım', 'quantity' => 1, 'unit_price_minor' => 100000, 'tax_rate' => 20],
            ],
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.code', 'PRO-0001')
            ->assertJsonPath('data.total_minor', 120000)
            ->assertJsonCount(1, 'data.items');

        $this->assertNotNull($response->json('data.created_at'));
    }

    public function test_rejects_proforma_for_a_customer_belonging_to_another_company(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $foreignCustomer = Customer::factory()->create();

        $this->postJson('/api/v1/proformas', [
            'code' => 'PRO-0002',
            'customer_id' => $foreignCustomer->id,
            'items' => [['description' => 'Test', 'quantity' => 1, 'unit_price_minor' => 1000]],
        ])->assertUnprocessable()->assertJsonValidationErrors('customer_id');
    }

    public function test_cannot_access_another_companys_proforma(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $foreignProforma = Proforma::factory()->create(['company_id' => $userB->company_id]);

        $this->withToken($userA->createToken('test')->plainTextToken)
            ->getJson("/api/v1/proformas/{$foreignProforma->id}")
            ->assertNotFound();
    }
}
