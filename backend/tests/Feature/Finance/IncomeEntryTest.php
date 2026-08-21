<?php

declare(strict_types=1);

namespace Tests\Feature\Finance;

use App\Models\IncomeEntry;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class IncomeEntryTest extends TestCase
{
    use RefreshDatabase;

    public function test_creates_an_income_entry(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->postJson('/api/v1/income-entries', [
            'description' => 'Servis geliri',
            'category' => 'Servis',
            'amount_minor' => 75000,
            'method' => 'Nakit',
        ])->assertCreated()->assertJsonPath('data.amount_minor', 75000);
    }

    public function test_rejects_an_invalid_category(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->postJson('/api/v1/income-entries', [
            'description' => 'Test', 'category' => 'GecersizKategori', 'amount_minor' => 1000, 'method' => 'Nakit',
        ])->assertUnprocessable()->assertJsonValidationErrors('category');
    }

    public function test_lists_only_the_authenticated_companys_income_entries(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        IncomeEntry::factory()->count(2)->create(['company_id' => $user->company_id]);
        IncomeEntry::factory()->count(3)->create();

        $this->getJson('/api/v1/income-entries')->assertOk()->assertJsonCount(2, 'data');
    }
}
