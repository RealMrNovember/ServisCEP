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

        // created_at, DB'nin useCurrent() varsayılanıyla doluyor — service
        // katmanı dönen Job'ı refresh() etmezse null görünür (gerçek
        // production bug'ı, smoke test ile bulundu ve düzeltildi).
        $this->assertNotNull($response->json('data.created_at'));

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

    public function test_convert_accepts_client_generated_job_id_and_replay_is_idempotent(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $serviceRequest = ServiceRequest::factory()->create([
            'company_id' => $user->company_id,
            'status' => 'BEKLIYOR',
        ]);

        $clientJobId = '3f7c2b9a-1d4e-4f6a-8b2c-9e5d7a1c3b6f';

        // Mobilin offline oluşturduğu işin UUID'si korunmalı — job.customer_id
        // gibi ilişkiler senkron sonrası kopmamalı (AcceptsClientGeneratedId
        // ile aynı gerekçe).
        $this->postJson("/api/v1/service-requests/{$serviceRequest->id}/convert", [
            'job_id' => $clientJobId,
        ])->assertCreated()->assertJsonPath('data.id', $clientJobId);

        // Ağ kesintisi sonrası replay: aynı talep + aynı job_id → hata değil,
        // var olan iş 200 ile döner (duplicate iş oluşmaz).
        $this->postJson("/api/v1/service-requests/{$serviceRequest->id}/convert", [
            'job_id' => $clientJobId,
        ])->assertOk()->assertJsonPath('data.id', $clientJobId);

        $this->assertSame(1, \App\Models\Job::where('id', $clientJobId)->count());

        // Farklı bir job_id ile tekrar dönüştürme denemesi hâlâ reddedilir.
        $this->postJson("/api/v1/service-requests/{$serviceRequest->id}/convert", [
            'job_id' => 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        ])->assertUnprocessable()->assertJsonValidationErrors('status');
    }
}
