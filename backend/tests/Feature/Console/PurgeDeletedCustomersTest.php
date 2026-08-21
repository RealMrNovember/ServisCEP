<?php

declare(strict_types=1);

namespace Tests\Feature\Console;

use App\Models\Customer;
use App\Models\Job;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Bkz. ROADMAP.md § B10 — geri dönüşüm kutusu günlük temizliği.
 */
class PurgeDeletedCustomersTest extends TestCase
{
    use RefreshDatabase;

    public function test_purges_a_customer_with_no_history_after_the_retention_window(): void
    {
        $customer = Customer::factory()->create();
        $customer->delete();
        $customer->forceFill(['deleted_at' => now()->subDays(4)])->save();

        $this->artisan('customers:purge-trash')->assertExitCode(0);

        $this->assertDatabaseMissing('customers', ['id' => $customer->id]);
    }

    public function test_does_not_purge_a_customer_within_the_retention_window(): void
    {
        $customer = Customer::factory()->create();
        $customer->delete();
        $customer->forceFill(['deleted_at' => now()->subDays(1)])->save();

        $this->artisan('customers:purge-trash')->assertExitCode(0);

        $this->assertDatabaseHas('customers', ['id' => $customer->id]);
    }

    public function test_does_not_purge_a_customer_with_job_history_even_after_the_window(): void
    {
        $customer = Customer::factory()->create();
        Job::factory()->create(['customer_id' => $customer->id, 'company_id' => $customer->company_id]);
        $customer->delete();
        $customer->forceFill(['deleted_at' => now()->subDays(10)])->save();

        $this->artisan('customers:purge-trash')->assertExitCode(0);

        $this->assertDatabaseHas('customers', ['id' => $customer->id]);
    }
}
