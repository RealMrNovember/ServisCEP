<?php

declare(strict_types=1);

namespace Tests\Feature\Job;

use App\Models\Job;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * İş tamamlandı + gerçek fiyat girildiğinde otomatik BORÇ kaydı —
 * bkz. docs/15 § Otomatik Kayıt Oluşturma.
 */
class JobCompletionLedgerTest extends TestCase
{
    use RefreshDatabase;

    public function test_completing_a_job_with_a_price_creates_a_debit_ledger_entry(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $job = Job::factory()->create(['company_id' => $user->company_id, 'status' => 'DEVAM_EDIYOR']);

        $this->putJson("/api/v1/jobs/{$job->id}", ['base_version' => 1, 'status' => 'TAMAMLANDI', 'actual_price_minor' => 150000])
            ->assertOk();

        $this->assertDatabaseHas('customer_ledger_entries', [
            'customer_id' => $job->customer_id,
            'type' => 'DEBIT',
            'amount_minor' => 150000,
            'reference_type' => 'job',
            'reference_id' => $job->id,
        ]);
    }

    public function test_completing_a_job_without_a_price_does_not_create_a_ledger_entry(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $job = Job::factory()->create(['company_id' => $user->company_id, 'status' => 'DEVAM_EDIYOR']);

        $this->putJson("/api/v1/jobs/{$job->id}", ['base_version' => 1, 'status' => 'TAMAMLANDI'])->assertOk();

        $this->assertDatabaseMissing('customer_ledger_entries', ['reference_type' => 'job', 'reference_id' => $job->id]);
    }

    public function test_adding_a_price_after_completion_still_creates_the_debit_entry_once(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $job = Job::factory()->create(['company_id' => $user->company_id, 'status' => 'DEVAM_EDIYOR']);

        // Her başarılı güncelleme version'ı artırır (HasVersion) — ikinci
        // istek bu yüzden base_version=2 göndermeli.
        $this->putJson("/api/v1/jobs/{$job->id}", ['base_version' => 1, 'status' => 'TAMAMLANDI'])->assertOk();
        $this->putJson("/api/v1/jobs/{$job->id}", ['base_version' => 2, 'actual_price_minor' => 80000])->assertOk();

        $this->assertDatabaseHas('customer_ledger_entries', [
            'reference_type' => 'job', 'reference_id' => $job->id, 'amount_minor' => 80000,
        ]);
        $this->assertDatabaseCount('customer_ledger_entries', 1);
    }

    public function test_editing_an_already_completed_job_does_not_duplicate_the_ledger_entry(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $job = Job::factory()->create(['company_id' => $user->company_id, 'status' => 'DEVAM_EDIYOR']);

        $this->putJson("/api/v1/jobs/{$job->id}", ['base_version' => 1, 'status' => 'TAMAMLANDI', 'actual_price_minor' => 150000])->assertOk();
        $this->putJson("/api/v1/jobs/{$job->id}", ['base_version' => 2, 'notes' => 'ek not'])->assertOk();

        $this->assertDatabaseCount('customer_ledger_entries', 1);
    }
}
