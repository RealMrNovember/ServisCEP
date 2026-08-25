<?php

declare(strict_types=1);

namespace Tests\Feature\Subscription;

use App\Models\Company;
use App\Models\Plan;
use App\Services\SubscriptionService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

/**
 * Panelde yazan sure gercekten uygulaniyor mu.
 *
 * Onceden `duration_days` alani tamamen yok sayiliyor, sabit 1 ay / 12 ay
 * ekleniyordu: panelde 90 gun yazan bir pakete odeme yapan musteri 30 gun
 * aliyordu ve kimse fark etmiyordu.
 */
class PlanDurationTest extends TestCase
{
    use RefreshDatabase;

    private function plan(?int $aylik, ?int $yillik): Plan
    {
        return Plan::create([
            'name' => 'Test',
            'slug' => 'test-'.uniqid(),
            'price_minor' => 100000,
            'price_yearly_minor' => 1000000,
            'duration_days' => $aylik,
            'duration_days_yearly' => $yillik,
        ]);
    }

    public function test_monthly_uses_plan_duration_days(): void
    {
        $plan = $this->plan(90, 365);
        $company = Company::factory()->create(['subscription_expires_at' => null]);

        app(SubscriptionService::class)->applyForPlan($company, $plan, 'MONTHLY');

        $this->assertSame(
            90,
            (int) round(Carbon::now()->diffInDays($company->refresh()->subscription_expires_at, false)),
        );
    }

    public function test_yearly_uses_its_own_field_not_twelve_times_monthly(): void
    {
        // 12 x 30 = 360 hesabi musteriye sessizce 5 gun kaybettirirdi.
        $plan = $this->plan(30, 365);
        $company = Company::factory()->create(['subscription_expires_at' => null]);

        app(SubscriptionService::class)->applyForPlan($company, $plan, 'YEARLY');

        $this->assertSame(
            365,
            (int) round(Carbon::now()->diffInDays($company->refresh()->subscription_expires_at, false)),
        );
    }

    public function test_missing_values_fall_back_to_sane_defaults(): void
    {
        $plan = $this->plan(null, null);
        $company = Company::factory()->create(['subscription_expires_at' => null]);

        app(SubscriptionService::class)->applyForPlan($company, $plan, 'MONTHLY');

        $this->assertSame(
            30,
            (int) round(Carbon::now()->diffInDays($company->refresh()->subscription_expires_at, false)),
        );
    }

    public function test_early_renewal_adds_to_remaining_time(): void
    {
        // Suresi bitmeden yenileyen kullanici kalan gunlerini kaybetmemeli.
        $plan = $this->plan(30, 365);
        $company = Company::factory()->create([
            'subscription_expires_at' => Carbon::now()->addDays(10),
        ]);

        app(SubscriptionService::class)->applyForPlan($company, $plan, 'MONTHLY');

        $this->assertSame(
            40,
            (int) round(Carbon::now()->diffInDays($company->refresh()->subscription_expires_at, false)),
        );
    }

    public function test_expired_subscription_starts_from_today(): void
    {
        $plan = $this->plan(30, 365);
        $company = Company::factory()->create([
            'subscription_expires_at' => Carbon::now()->subDays(20),
        ]);

        app(SubscriptionService::class)->applyForPlan($company, $plan, 'MONTHLY');

        $this->assertSame(
            30,
            (int) round(Carbon::now()->diffInDays($company->refresh()->subscription_expires_at, false)),
        );
    }
}
