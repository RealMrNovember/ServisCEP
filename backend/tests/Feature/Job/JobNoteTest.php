<?php

declare(strict_types=1);

namespace Tests\Feature\Job;

use App\Models\Job;
use App\Models\JobNote;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class JobNoteTest extends TestCase
{
    use RefreshDatabase;

    public function test_creates_and_lists_notes_for_a_job(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $job = Job::factory()->create(['company_id' => $user->company_id]);

        $this->postJson("/api/v1/jobs/{$job->id}/notes", ['note' => 'Müşteri aradı.'])
            ->assertCreated()
            ->assertJsonPath('data.note', 'Müşteri aradı.');

        $this->getJson("/api/v1/jobs/{$job->id}/notes")
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_deletes_a_note(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $job = Job::factory()->create(['company_id' => $user->company_id]);
        $note = JobNote::factory()->create(['job_id' => $job->id]);

        $this->deleteJson("/api/v1/jobs/{$job->id}/notes/{$note->id}")->assertNoContent();

        $this->assertDatabaseMissing('job_notes', ['id' => $note->id]);
    }

    public function test_cannot_access_notes_of_another_companys_job(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $foreignJob = Job::factory()->create(['company_id' => $userB->company_id]);

        $this->withToken($userA->createToken('test')->plainTextToken)
            ->getJson("/api/v1/jobs/{$foreignJob->id}/notes")
            ->assertNotFound();
    }

    public function test_cannot_delete_a_note_belonging_to_a_different_job(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $jobA = Job::factory()->create(['company_id' => $user->company_id]);
        $jobB = Job::factory()->create(['company_id' => $user->company_id]);
        $note = JobNote::factory()->create(['job_id' => $jobB->id]);

        $this->deleteJson("/api/v1/jobs/{$jobA->id}/notes/{$note->id}")->assertNotFound();

        $this->assertDatabaseHas('job_notes', ['id' => $note->id]);
    }
}
