<?php

declare(strict_types=1);

namespace Tests\Feature\Job;

use App\Models\Job;
use App\Models\JobPhoto;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class JobPhotoTest extends TestCase
{
    use RefreshDatabase;

    public function test_uploads_a_photo_and_stores_it_outside_the_public_disk(): void
    {
        Storage::fake('local');

        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;
        $job = Job::factory()->create(['company_id' => $user->company_id]);

        $file = UploadedFile::fake()->create('before.jpg', 500, 'image/jpeg');

        $response = $this->withToken($token)->postJson("/api/v1/jobs/{$job->id}/photos", [
            'category' => 'ONCESI',
            'file' => $file,
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.category', 'ONCESI')
            ->assertJsonStructure(['data' => ['id', 'download_url', 'signed_url']]);

        $photo = JobPhoto::first();
        Storage::disk('local')->assertExists($photo->file_path);
        // company_id, dosya yolunda geçmeli — bkz. docs/09 § Dosya Güvenliği.
        $this->assertStringContainsString((string) $user->company_id, $photo->file_path);
    }

    public function test_rejects_non_image_uploads(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;
        $job = Job::factory()->create(['company_id' => $user->company_id]);

        $file = UploadedFile::fake()->create('malware.exe', 10, 'application/x-msdownload');

        $this->withToken($token)
            ->postJson("/api/v1/jobs/{$job->id}/photos", ['category' => 'ONCESI', 'file' => $file])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('file');
    }

    public function test_downloads_a_photo_with_an_authenticated_request(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;
        $job = Job::factory()->create(['company_id' => $user->company_id]);

        $upload = $this->withToken($token)->postJson("/api/v1/jobs/{$job->id}/photos", [
            'category' => 'ONCESI',
            'file' => UploadedFile::fake()->create('before.jpg', 100, 'image/jpeg'),
        ]);
        $photoId = $upload->json('data.id');

        $this->withToken($token)->get("/api/v1/jobs/{$job->id}/photos/{$photoId}/download")->assertOk();
    }

    public function test_downloads_a_photo_via_signed_url_without_a_token(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;
        $job = Job::factory()->create(['company_id' => $user->company_id]);

        $upload = $this->withToken($token)->postJson("/api/v1/jobs/{$job->id}/photos", [
            'category' => 'ONCESI',
            'file' => UploadedFile::fake()->create('before.jpg', 100, 'image/jpeg'),
        ]);
        $signedUrl = $upload->json('data.signed_url');

        // Bilerek Authorization header'ı olmayan taze bir istek kullanılıyor
        // — signed URL'nin tek başına yeterli olduğunu kanıtlar.
        $this->get($signedUrl)->assertOk();
    }

    public function test_rejects_a_tampered_signed_url(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;
        $job = Job::factory()->create(['company_id' => $user->company_id]);

        $upload = $this->withToken($token)->postJson("/api/v1/jobs/{$job->id}/photos", [
            'category' => 'ONCESI',
            'file' => UploadedFile::fake()->create('before.jpg', 100, 'image/jpeg'),
        ]);
        $photoId = $upload->json('data.id');

        $this->get("/api/v1/files/photos/{$photoId}")->assertForbidden();
    }

    public function test_deletes_a_photo_and_its_underlying_file(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;
        $job = Job::factory()->create(['company_id' => $user->company_id]);

        $upload = $this->withToken($token)->postJson("/api/v1/jobs/{$job->id}/photos", [
            'category' => 'ONCESI',
            'file' => UploadedFile::fake()->create('before.jpg', 100, 'image/jpeg'),
        ]);
        $photo = JobPhoto::findOrFail($upload->json('data.id'));

        $this->withToken($token)->deleteJson("/api/v1/jobs/{$job->id}/photos/{$photo->id}")->assertNoContent();

        $this->assertDatabaseMissing('job_photos', ['id' => $photo->id]);
        Storage::disk('local')->assertMissing($photo->file_path);
    }

    public function test_cannot_access_photos_of_another_companys_job(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $foreignJob = Job::factory()->create(['company_id' => $userB->company_id]);

        $this->withToken($userA->createToken('test')->plainTextToken)
            ->getJson("/api/v1/jobs/{$foreignJob->id}/photos")
            ->assertNotFound();
    }
}
