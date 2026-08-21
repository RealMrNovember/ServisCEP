<?php

declare(strict_types=1);

namespace Tests\Feature\Job;

use App\Models\Job;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class JobSignatureTest extends TestCase
{
    use RefreshDatabase;

    public function test_uploads_and_downloads_a_signature(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $job = Job::factory()->create(['company_id' => $user->company_id]);

        $response = $this->postJson("/api/v1/jobs/{$job->id}/signatures", [
            'signer_name' => 'Ahmet Yılmaz',
            'file' => UploadedFile::fake()->create('imza.png', 50, 'image/png'),
        ]);

        $response->assertCreated()->assertJsonPath('data.signer_name', 'Ahmet Yılmaz');

        $signatureId = $response->json('data.id');
        $this->get("/api/v1/jobs/{$job->id}/signatures/{$signatureId}/download")->assertOk();
    }

    public function test_cannot_access_signatures_of_another_companys_job(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $foreignJob = Job::factory()->create(['company_id' => $userB->company_id]);

        $this->withToken($userA->createToken('test')->plainTextToken)
            ->getJson("/api/v1/jobs/{$foreignJob->id}/signatures")
            ->assertNotFound();
    }
}
