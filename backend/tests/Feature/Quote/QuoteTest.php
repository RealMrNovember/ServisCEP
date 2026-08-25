<?php

declare(strict_types=1);

namespace Tests\Feature\Quote;

use App\Models\Customer;
use App\Models\Quote;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class QuoteTest extends TestCase
{
    use RefreshDatabase;

    public function test_creates_a_quote_with_items_and_calculates_total(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $response = $this->postJson('/api/v1/quotes', [
            'code' => 'TEK-0001',
            'customer_id' => $customer->id,
            'items' => [
                // 2 * 10000 = 20000 - 1000 iskonto = 19000, %20 KDV -> 22800
                ['description' => 'Kamera montajı', 'quantity' => 2, 'unit_price_minor' => 10000, 'discount_minor' => 1000, 'tax_rate' => 20],
                // 1 * 5000 = 5000, %0 KDV -> 5000
                ['description' => 'Kablo', 'quantity' => 1, 'unit_price_minor' => 5000, 'tax_rate' => 0],
            ],
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.code', 'TEK-0001')
            ->assertJsonPath('data.status', 'TASLAK')
            ->assertJsonPath('data.total_minor', 27800)
            ->assertJsonCount(2, 'data.items');

        $this->assertNotNull($response->json('data.created_at'));
    }

    public function test_stores_document_texts_and_returns_them(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        // Belge metinleri belge OLUSTURULURKEN kopyalanir; sirket ayari
        // sonradan degisse bile gonderilmis teklifin sartlari degismemeli.
        $response = $this->postJson('/api/v1/quotes', [
            'code' => 'TKF-2026-00042',
            'customer_id' => $customer->id,
            'currency' => 'USD',
            'vat_mode' => 'INCLUDED',
            'vat_rate' => 10,
            'intro_text' => 'Sayin Yetkili, teklifimiz ektedir.',
            'payment_terms' => '%50 avans, %50 teslimatta.',
            'delivery_time' => '5 is gunu.',
            'warranty_terms' => '2 yil urun garantisi.',
            'items' => [
                ['description' => 'Montaj', 'quantity' => 1, 'unit_price_minor' => 10000],
            ],
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.currency', 'USD')
            ->assertJsonPath('data.vat_mode', 'INCLUDED')
            ->assertJsonPath('data.vat_rate', 10)
            ->assertJsonPath('data.intro_text', 'Sayin Yetkili, teklifimiz ektedir.')
            ->assertJsonPath('data.payment_terms', '%50 avans, %50 teslimatta.')
            ->assertJsonPath('data.delivery_time', '5 is gunu.')
            ->assertJsonPath('data.warranty_terms', '2 yil urun garantisi.');
    }

    public function test_document_number_is_taken_from_the_client(): void
    {
        // Numara istemcide uretilir (offline calisabilmesi icin) ve sunucu
        // onu oldugu gibi saklar; kullanicinin elle degistirdigi numara
        // sunucuda yeniden uretilip ezilmemeli.
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->postJson('/api/v1/quotes', [
            'code' => 'TEKLIF-2026-01500',
            'customer_id' => $customer->id,
            'items' => [
                ['description' => 'Montaj', 'quantity' => 1, 'unit_price_minor' => 10000],
            ],
        ])->assertCreated()->assertJsonPath('data.code', 'TEKLIF-2026-01500');

        $this->assertDatabaseHas('quotes', ['code' => 'TEKLIF-2026-01500']);
    }

    public function test_rejects_quote_for_a_customer_belonging_to_another_company(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $foreignCustomer = Customer::factory()->create();

        $this->postJson('/api/v1/quotes', [
            'code' => 'TEK-0002',
            'customer_id' => $foreignCustomer->id,
            'items' => [['description' => 'Test', 'quantity' => 1, 'unit_price_minor' => 1000]],
        ])->assertUnprocessable()->assertJsonValidationErrors('customer_id');
    }

    public function test_updates_quote_status(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $quote = Quote::factory()->create(['company_id' => $user->company_id]);

        $this->putJson("/api/v1/quotes/{$quote->id}", ['base_version' => 1, 'status' => 'GONDERILDI'])
            ->assertOk()
            ->assertJsonPath('data.status', 'GONDERILDI');
    }

    public function test_cannot_access_another_companys_quote(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $foreignQuote = Quote::factory()->create(['company_id' => $userB->company_id]);

        $this->withToken($userA->createToken('test')->plainTextToken)
            ->getJson("/api/v1/quotes/{$foreignQuote->id}")
            ->assertNotFound();
    }
}
