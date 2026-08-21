<?php

declare(strict_types=1);

namespace Tests\Feature\ServiceRequest;

use App\Models\ServiceRequest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Talep -> İş dönüşümü — bkz. docs/02 § Talep → İş Dönüşümü: müşteri,
 * açıklama, öncelik, adres otomatik taşınmalıdır.
 */
class ServiceRequestConvertTest extends TestCase
{
    use RefreshDatabase;

    public function test_converts_a_service_request_into_a_job_carrying_its_context(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $serviceRequest = ServiceRequest::factory()->create([
            'company_id' => $user->company_id,
            'description' => '3 kamera görüntü vermiyor.',
            'priority' => 'YUKSEK',
            'address' => 'Kadıköy / İstanbul',
            'status' => 'BEKLIYOR',
        ]);

        $response = $this->postJson("/api/v1/service-requests/{$serviceRequest->id}/convert");

        $response->assertCreated()
            ->assertJsonPath('data.customer_id', $serviceRequest->customer_id)
            ->assertJsonPath('data.description', '3 kamera görüntü vermiyor.')
            ->assertJsonPath('data.priority', 'YUKSEK')
            ->assertJsonPath('data.address', 'Kadıköy / İstanbul')
            ->assertJsonPath('data.status', 'TALEP');

        $jobId = $response->json('data.id');

        $this->assertDatabaseHas('service_requests', [
            'id' => $serviceRequest->id,
            'status' => 'ISE_DONUSTU',
            'converted_job_id' => $jobId,
        ]);

        $this->assertDatabaseHas('jobs', ['id' => $jobId, 'company_id' => $user->company_id]);
    }

    public function test_cannot_convert_an_already_converted_service_request_twice(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $serviceRequest = ServiceRequest::factory()->create([
            'company_id' => $user->company_id,
            'status' => 'BEKLIYOR',
        ]);

        $this->postJson("/api/v1/service-requests/{$serviceRequest->id}/convert")->assertCreated();

        $this->postJson("/api/v1/service-requests/{$serviceRequest->id}/convert")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('status');
    }
}
