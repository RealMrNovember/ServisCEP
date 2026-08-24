<?php

declare(strict_types=1);

namespace Tests\Feature\Customer;

use App\Models\Customer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Vergi levhası (müşteri belgesi) — web panelindeki FileUpload alanının
 * mobil API karşılığı. Dosya private disk'te tutulmalı, ham yol asla
 * JSON'a sızmamalı (bkz. docs/09 § Dosya Güvenliği).
 *
 * NOT: `UploadedFile::fake()->image()` GD eklentisi ister; testleri
 * çalıştırdığımız `composer:2` imajında GD yok (production imajında var).
 * Bu yüzden sahte dosyalar `create(..., mimeType)` ile üretiliyor —
 * doğrulama kuralları açısından farkı yok.
 */
class CustomerTaxCertificateTest extends TestCase
{
    use RefreshDatabase;

    public function test_uploads_stores_privately_and_exposes_only_urls(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $response = $this->postJson("/api/v1/customers/{$customer->id}/tax-certificate", [
            'file' => UploadedFile::fake()->create('levha.pdf', 120, 'application/pdf'),
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.has_tax_certificate', true)
            ->assertJsonStructure(['data' => ['tax_certificate_download_url', 'tax_certificate_signed_url']]);

        // Ham dosya yolu istemciye asla verilmez.
        $this->assertStringNotContainsString('tax_certificate_path', $response->getContent());

        $customer->refresh();
        $this->assertStringStartsWith("tax-certificates/{$user->company_id}", $customer->tax_certificate_path);
        Storage::disk('local')->assertExists($customer->tax_certificate_path);
    }

    public function test_reupload_replaces_previous_file_without_orphaning_it(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->postJson("/api/v1/customers/{$customer->id}/tax-certificate", [
            'file' => UploadedFile::fake()->create('ilk.jpg', 80, 'image/jpeg'),
        ])->assertCreated();
        $firstPath = $customer->refresh()->tax_certificate_path;

        $this->postJson("/api/v1/customers/{$customer->id}/tax-certificate", [
            'file' => UploadedFile::fake()->create('ikinci.jpg', 80, 'image/jpeg'),
        ])->assertCreated();
        $secondPath = $customer->refresh()->tax_certificate_path;

        $this->assertNotSame($firstPath, $secondPath);
        Storage::disk('local')->assertMissing($firstPath);
        Storage::disk('local')->assertExists($secondPath);
    }

    public function test_rejects_unsupported_file_type(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->postJson("/api/v1/customers/{$customer->id}/tax-certificate", [
            'file' => UploadedFile::fake()->create('zararli.exe', 10),
        ])->assertUnprocessable()->assertJsonValidationErrors('file');
    }

    public function test_another_company_cannot_upload_or_download(): void
    {
        Storage::fake('local');
        $owner = User::factory()->create();
        $customer = Customer::factory()->create(['company_id' => $owner->company_id]);

        $intruder = User::factory()->create();
        $this->withToken($intruder->createToken('test')->plainTextToken);

        $this->postJson("/api/v1/customers/{$customer->id}/tax-certificate", [
            'file' => UploadedFile::fake()->create('levha.jpg', 80, 'image/jpeg'),
        ])->assertNotFound();

        $this->getJson("/api/v1/customers/{$customer->id}/tax-certificate")->assertNotFound();
    }

    public function test_download_and_delete_flow(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->postJson("/api/v1/customers/{$customer->id}/tax-certificate", [
            'file' => UploadedFile::fake()->create('levha.jpg', 80, 'image/jpeg'),
        ])->assertCreated();
        $path = $customer->refresh()->tax_certificate_path;

        $this->get("/api/v1/customers/{$customer->id}/tax-certificate")->assertOk();

        $this->deleteJson("/api/v1/customers/{$customer->id}/tax-certificate")
            ->assertOk()
            ->assertJsonPath('data.has_tax_certificate', false);

        Storage::disk('local')->assertMissing($path);
        $this->assertNull($customer->refresh()->tax_certificate_path);
    }
}
