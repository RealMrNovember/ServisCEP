<?php

declare(strict_types=1);

namespace Tests\Feature\Finance;

use App\Models\ExpenseEntry;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExpenseEntryTest extends TestCase
{
    use RefreshDatabase;

    public function test_creates_an_expense_entry(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->postJson('/api/v1/expense-entries', [
            'description' => 'Yakıt gideri',
            'category' => 'Yakıt',
            'amount_minor' => 30000,
            'vendor_name' => 'Shell',
            'method' => 'Kredi Kartı',
        ])->assertCreated()->assertJsonPath('data.vendor_name', 'Shell');
    }

    public function test_rejects_an_invalid_category(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->postJson('/api/v1/expense-entries', [
            'description' => 'Test', 'category' => 'GecersizKategori', 'amount_minor' => 1000, 'method' => 'Nakit',
        ])->assertUnprocessable()->assertJsonValidationErrors('category');
    }

    public function test_lists_only_the_authenticated_companys_expense_entries(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        ExpenseEntry::factory()->count(2)->create(['company_id' => $user->company_id]);
        ExpenseEntry::factory()->count(3)->create();

        $this->getJson('/api/v1/expense-entries')->assertOk()->assertJsonCount(2, 'data');
    }
}
