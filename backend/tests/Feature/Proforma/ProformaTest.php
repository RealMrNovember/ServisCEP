<?php

declare(strict_types=1);

namespace Tests\Feature\Proforma;

use App\Models\Customer;
use App\Models\Proforma;
use App\Models\ProformaItem;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class ProformaTest extends TestCase
{
    use RefreshDatabase;

    public function test_creates_a_proforma_with_items_and_calculates_total(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $response = $this->postJson('/api/v1/proformas', [
            'code' => 'PRO-0001',
            'customer_id' => $customer->id,
            'valid_until' => now()->addDays(15)->toDateString(),
            'items' => [
                ['description' => 'Bakım', 'quantity' => 1, 'unit_price_minor' => 100000, 'tax_rate' => 20],
            ],
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.code', 'PRO-0001')
            ->assertJsonPath('data.total_minor', 120000)
            ->assertJsonCount(1, 'data.items');

        $this->assertNotNull($response->json('data.created_at'));
    }

    public function test_rejects_proforma_for_a_customer_belonging_to_another_company(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $foreignCustomer = Customer::factory()->create();

        $this->postJson('/api/v1/proformas', [
            'code' => 'PRO-0002',
            'customer_id' => $foreignCustomer->id,
            'items' => [['description' => 'Test', 'quantity' => 1, 'unit_price_minor' => 1000]],
        ])->assertUnprocessable()->assertJsonValidationErrors('customer_id');
    }

    public function test_cannot_access_another_companys_proforma(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $foreignProforma = Proforma::factory()->create(['company_id' => $userB->company_id]);

        $this->withToken($userA->createToken('test')->plainTextToken)
            ->getJson("/api/v1/proformas/{$foreignProforma->id}")
            ->assertNotFound();
    }

    public function test_updating_items_replaces_them_and_marks_the_document_as_edited(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $created = $this->postJson('/api/v1/proformas', [
            'code' => 'PRO-0010',
            'customer_id' => $customer->id,
            'items' => [
                ['description' => 'Bakım', 'quantity' => 1, 'unit_price_minor' => 100000, 'tax_rate' => 20],
            ],
        ])->assertCreated();

        $this->assertNull($created->json('data.edited_at'), 'Yeni olusturulan belge duzenlenmis gorunmemeli.');

        $id = $created->json('data.id');

        $response = $this->putJson("/api/v1/proformas/{$id}", [
            'base_version' => $created->json('data.version'),
            'changed_fields' => ['total_minor', 'edited_at'],
            'items' => [
                ['description' => 'Bakım', 'quantity' => 2, 'unit_price_minor' => 100000, 'tax_rate' => 20],
                ['description' => 'Kablo', 'quantity' => 3, 'unit_price_minor' => 50000, 'tax_rate' => 20],
            ],
        ]);

        // (2 x 1000) + (3 x 500) = 3500 net, %20 KDV ile 4200.
        $response->assertOk()
            ->assertJsonCount(2, 'data.items')
            ->assertJsonPath('data.total_minor', 420000);

        $this->assertNotNull($response->json('data.edited_at'), 'Kalem degisikligi belgeyi duzenlenmis isaretlemeli.');

        // Eski kalem silinmis olmali: liste kaydin yeni hali, eklenti degil.
        $this->assertSame(2, ProformaItem::where('proforma_id', $id)->count());
    }

    public function test_keeps_the_edit_time_reported_by_an_offline_client(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $created = $this->postJson('/api/v1/proformas', [
            'code' => 'PRO-0011',
            'customer_id' => $customer->id,
            'items' => [['description' => 'Bakım', 'quantity' => 1, 'unit_price_minor' => 100000]],
        ])->assertCreated();

        // Telefon uc gun once offline duzenlemis, bugun senkron oluyor.
        $duzenlemeAni = now()->subDays(3)->startOfSecond();

        $response = $this->putJson("/api/v1/proformas/{$created->json('data.id')}", [
            'base_version' => $created->json('data.version'),
            'changed_fields' => ['total_minor', 'edited_at'],
            'edited_at' => $duzenlemeAni->toIso8601String(),
            'items' => [['description' => 'Bakım', 'quantity' => 2, 'unit_price_minor' => 100000]],
        ])->assertOk();

        $this->assertSame(
            $duzenlemeAni->toIso8601String(),
            Carbon::parse($response->json('data.edited_at'))->toIso8601String(),
            'Senkron saati degil, gercek duzenleme ani saklanmali.'
        );
    }
}
