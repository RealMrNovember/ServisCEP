<?php

declare(strict_types=1);

namespace Tests\Feature\Customer;

use App\Models\Customer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CustomerCrudTest extends TestCase
{
    use RefreshDatabase;

    private function actingUser(): User
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        return $user;
    }

    public function test_creates_a_customer_scoped_to_the_authenticated_users_company(): void
    {
        $user = $this->actingUser();

        $response = $this->postJson('/api/v1/customers', [
            'code' => 'M-0001',
            'contact_name' => 'Ahmet Yılmaz',
            'type' => 'BIREYSEL',
            'phone' => '5551234567',
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.code', 'M-0001')
            ->assertJsonPath('data.display_name', 'Ahmet Yılmaz');

        $this->assertDatabaseHas('customers', [
            'code' => 'M-0001',
            'company_id' => $user->company_id,
        ]);
    }

    public function test_rejects_customer_without_contact_name_or_company_name(): void
    {
        $this->actingUser();

        $response = $this->postJson('/api/v1/customers', [
            'code' => 'M-0002',
            'type' => 'FIRMA',
        ]);

        $response->assertUnprocessable()->assertJsonValidationErrors('contact_name');
    }

    public function test_lists_only_the_authenticated_companys_customers(): void
    {
        $user = $this->actingUser();
        Customer::factory()->count(3)->create(['company_id' => $user->company_id]);
        Customer::factory()->count(2)->create();

        $this->getJson('/api/v1/customers')->assertOk()->assertJsonCount(3, 'data');
    }

    public function test_shows_a_single_customer(): void
    {
        $user = $this->actingUser();
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->getJson("/api/v1/customers/{$customer->id}")
            ->assertOk()
            ->assertJsonPath('data.id', $customer->id);
    }

    public function test_updates_a_customer(): void
    {
        $user = $this->actingUser();
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->putJson("/api/v1/customers/{$customer->id}", ['phone' => '5559998877'])
            ->assertOk()
            ->assertJsonPath('data.phone', '5559998877');

        $this->assertDatabaseHas('customers', ['id' => $customer->id, 'phone' => '5559998877']);
    }

    public function test_soft_deletes_a_customer(): void
    {
        $user = $this->actingUser();
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->deleteJson("/api/v1/customers/{$customer->id}")->assertNoContent();

        $this->assertSoftDeleted('customers', ['id' => $customer->id]);
    }
}
