<?php

declare(strict_types=1);

namespace Tests\Feature\Sync;

use App\Models\Customer;
use App\Models\Job;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * Bkz. ROADMAP.md § B10 — mobil offline oluşturduğu kaydın UUID'sini
 * korumalıdır (aksi halde ilişkili kayıtlar sunucuda farklı bir ID'ye
 * referans vermiş olur). Aynı ID ile tekrar gelen bir create isteği
 * (ör. ağ kesintisi sonrası retry) hataya değil, var olan kaydı
 * döndürerek karşılanmalıdır.
 */
class IdempotentCreateTest extends TestCase
{
    use RefreshDatabase;

    public function test_create_preserves_the_client_supplied_uuid(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $clientId = (string) Str::uuid();

        $response = $this->postJson('/api/v1/customers', [
            'id' => $clientId, 'code' => 'M-1', 'contact_name' => 'Test', 'type' => 'BIREYSEL',
        ]);

        $response->assertCreated()->assertJsonPath('data.id', $clientId);
        $this->assertDatabaseHas('customers', ['id' => $clientId]);
    }

    public function test_replaying_the_same_create_request_returns_the_existing_record_without_duplicating(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $clientId = (string) Str::uuid();
        $payload = ['id' => $clientId, 'code' => 'M-1', 'contact_name' => 'Test', 'type' => 'BIREYSEL'];

        $this->postJson('/api/v1/customers', $payload)->assertCreated();

        // Ağ kesintisi sonrası retry senaryosu — aynı istek tekrar gönderilir.
        $this->postJson('/api/v1/customers', $payload)
            ->assertOk()
            ->assertJsonPath('data.id', $clientId);

        $this->assertDatabaseCount('customers', 1);
    }

    public function test_offline_created_records_keep_their_relationship_intact_after_sync(): void
    {
        // Mobil, offline'ken hem müşteriyi hem de o müşteriye bağlı işi
        // aynı anda (her ikisi de kendi client UUID'siyle) oluşturur.
        // Bağlantının kopmaması için her iki ID de sunucuda korunmalıdır.
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customerId = (string) Str::uuid();
        $jobId = (string) Str::uuid();

        $this->postJson('/api/v1/customers', [
            'id' => $customerId, 'code' => 'M-1', 'contact_name' => 'Test', 'type' => 'BIREYSEL',
        ])->assertCreated();

        $this->postJson('/api/v1/jobs', [
            'id' => $jobId, 'code' => 'J-1', 'customer_id' => $customerId,
            'title' => 'Offline iş', 'priority' => 'NORMAL', 'status' => 'TALEP',
        ])->assertCreated();

        $job = Job::findOrFail($jobId);
        $this->assertSame($customerId, $job->customer_id);
        $this->assertInstanceOf(Customer::class, $job->customer);
    }
}
