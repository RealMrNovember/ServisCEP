<?php

declare(strict_types=1);

namespace Tests\Feature\Job;

use App\Models\Customer;
use App\Models\Job;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class JobCrudTest extends TestCase
{
    use RefreshDatabase;

    private function actingUser(): User
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        return $user;
    }

    public function test_creates_a_job_for_a_customer_in_the_same_company(): void
    {
        $user = $this->actingUser();
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $response = $this->postJson('/api/v1/jobs', [
            'code' => 'J-0001',
            'customer_id' => $customer->id,
            'title' => 'Kamera arızası',
            'priority' => 'NORMAL',
            'status' => 'TALEP',
            'estimated_price_minor' => 150000,
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.title', 'Kamera arızası')
            ->assertJsonPath('data.estimated_price_minor', 150000);

        $this->assertNotNull($response->json('data.created_at'));
    }

    public function test_rejects_job_for_a_customer_belonging_to_another_company(): void
    {
        $this->actingUser();
        $foreignCustomer = Customer::factory()->create();

        $response = $this->postJson('/api/v1/jobs', [
            'code' => 'J-0002',
            'customer_id' => $foreignCustomer->id,
            'title' => 'Test',
            'priority' => 'NORMAL',
            'status' => 'TALEP',
        ]);

        $response->assertUnprocessable()->assertJsonValidationErrors('customer_id');
    }

    public function test_lists_only_the_authenticated_companys_jobs(): void
    {
        $user = $this->actingUser();
        Job::factory()->count(3)->create(['company_id' => $user->company_id]);
        Job::factory()->count(2)->create();

        $this->getJson('/api/v1/jobs')->assertOk()->assertJsonCount(3, 'data');
    }

    public function test_filters_jobs_by_status(): void
    {
        $user = $this->actingUser();
        Job::factory()->create(['company_id' => $user->company_id, 'status' => 'TAMAMLANDI']);
        Job::factory()->create(['company_id' => $user->company_id, 'status' => 'TALEP']);

        $this->getJson('/api/v1/jobs?status=TAMAMLANDI')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.status', 'TAMAMLANDI');
    }

    public function test_updates_a_job(): void
    {
        $user = $this->actingUser();
        $job = Job::factory()->create(['company_id' => $user->company_id]);

        $this->putJson("/api/v1/jobs/{$job->id}", ['status' => 'TAMAMLANDI', 'actual_price_minor' => 200000])
            ->assertOk()
            ->assertJsonPath('data.status', 'TAMAMLANDI')
            ->assertJsonPath('data.actual_price_minor', 200000);
    }

    public function test_cancels_a_job_via_status_instead_of_deleting_it(): void
    {
        // Bkz. docs/09 § Veri Silme Prensibi — kritik belgelerde (iş dahil)
        // silme yerine İPTAL durumu tercih edilir; API'de destroy yoktur.
        $user = $this->actingUser();
        $job = Job::factory()->create(['company_id' => $user->company_id]);

        $this->putJson("/api/v1/jobs/{$job->id}", ['status' => 'IPTAL'])
            ->assertOk()
            ->assertJsonPath('data.status', 'IPTAL');

        $this->assertDatabaseHas('jobs', ['id' => $job->id, 'status' => 'IPTAL', 'deleted_at' => null]);
    }
}
