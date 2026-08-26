<?php

declare(strict_types=1);

namespace Tests\Feature\Job;

use App\Models\Job;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class JobIsolationTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_company_cannot_view_another_companys_job(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $foreignJob = Job::factory()->create(['company_id' => $userB->company_id]);

        $tokenA = $userA->createToken('test')->plainTextToken;

        $this->withToken($tokenA)->getJson("/api/v1/jobs/{$foreignJob->id}")->assertNotFound();
    }

    public function test_a_company_cannot_update_another_companys_job(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $foreignJob = Job::factory()->create(['company_id' => $userB->company_id]);

        $tokenA = $userA->createToken('test')->plainTextToken;

        $this->withToken($tokenA)
            ->putJson("/api/v1/jobs/{$foreignJob->id}", ['status' => 'IPTAL'])
            ->assertNotFound();
    }
}
