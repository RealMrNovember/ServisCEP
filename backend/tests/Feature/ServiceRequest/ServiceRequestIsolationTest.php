<?php

declare(strict_types=1);

namespace Tests\Feature\ServiceRequest;

use App\Models\ServiceRequest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ServiceRequestIsolationTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_company_cannot_view_another_companys_service_request(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $foreign = ServiceRequest::factory()->create(['company_id' => $userB->company_id]);

        $tokenA = $userA->createToken('test')->plainTextToken;

        $this->withToken($tokenA)->getJson("/api/v1/service-requests/{$foreign->id}")
            ->assertNotFound();
    }

    public function test_a_company_cannot_update_another_companys_service_request(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $foreign = ServiceRequest::factory()->create(['company_id' => $userB->company_id]);

        $tokenA = $userA->createToken('test')->plainTextToken;

        $this->withToken($tokenA)
            ->putJson("/api/v1/service-requests/{$foreign->id}", ['priority' => 'YUKSEK'])
            ->assertNotFound();
    }

    public function test_a_company_cannot_convert_another_companys_service_request(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $foreign = ServiceRequest::factory()->create(['company_id' => $userB->company_id]);

        $tokenA = $userA->createToken('test')->plainTextToken;

        $this->withToken($tokenA)->postJson("/api/v1/service-requests/{$foreign->id}/convert")
            ->assertNotFound();
    }
}
