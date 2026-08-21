<?php

declare(strict_types=1);

namespace Tests\Feature\ServiceRequest;

use App\Models\Customer;
use App\Models\ServiceRequest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ServiceRequestCrudTest extends TestCase
{
    use RefreshDatabase;

    private function actingUser(): User
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        return $user;
    }

    public function test_creates_a_service_request_for_a_customer_in_the_same_company(): void
    {
        $user = $this->actingUser();
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $response = $this->postJson('/api/v1/service-requests', [
            'code' => 'T-0001',
            'customer_id' => $customer->id,
            'description' => '3 kamera görüntü vermiyor.',
            'priority' => 'YUKSEK',
            'address' => 'Kadıköy / İstanbul',
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.status', 'BEKLIYOR')
            ->assertJsonPath('data.priority', 'YUKSEK');

        $this->assertNotNull($response->json('data.created_at'));
    }

    public function test_rejects_service_request_for_a_customer_belonging_to_another_company(): void
    {
        $this->actingUser();
        $foreignCustomer = Customer::factory()->create();

        $response = $this->postJson('/api/v1/service-requests', [
            'code' => 'T-0002',
            'customer_id' => $foreignCustomer->id,
            'description' => 'Test',
            'priority' => 'NORMAL',
        ]);

        $response->assertUnprocessable()->assertJsonValidationErrors('customer_id');
    }

    public function test_lists_only_the_authenticated_companys_service_requests(): void
    {
        $user = $this->actingUser();
        ServiceRequest::factory()->count(2)->create(['company_id' => $user->company_id]);
        ServiceRequest::factory()->count(4)->create();

        $this->getJson('/api/v1/service-requests')->assertOk()->assertJsonCount(2, 'data');
    }

    public function test_updates_a_service_request(): void
    {
        $user = $this->actingUser();
        $serviceRequest = ServiceRequest::factory()->create(['company_id' => $user->company_id]);

        $this->putJson("/api/v1/service-requests/{$serviceRequest->id}", ['status' => 'ISLEME_ALINDI'])
            ->assertOk()
            ->assertJsonPath('data.status', 'ISLEME_ALINDI');
    }

    public function test_rejects_setting_status_to_ise_donustu_directly(): void
    {
        $user = $this->actingUser();
        $serviceRequest = ServiceRequest::factory()->create(['company_id' => $user->company_id]);

        $this->putJson("/api/v1/service-requests/{$serviceRequest->id}", ['status' => 'ISE_DONUSTU'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('status');
    }
}
