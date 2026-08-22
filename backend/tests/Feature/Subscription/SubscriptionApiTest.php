<?php

declare(strict_types=1);

namespace Tests\Feature\Subscription;

use App\Models\AdminUser;
use App\Models\Company;
use App\Models\PaymentRequest;
use App\Models\Plan;
use App\Models\Setting;
use App\Models\User;
use App\Notifications\NewPaymentRequestReceived;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class SubscriptionApiTest extends TestCase
{
    use RefreshDatabase;

    private function makePlan(array $overrides = []): Plan
    {
        return Plan::create(array_merge([
            'name' => 'Profesyonel',
            'slug' => 'profesyonel',
            'description' => '3-5 kişilik ekipler için. Dijital imza, cari hesap takibi.',
            'price_minor' => 100000,
            'price_yearly_minor' => 1100000,
            'duration_days' => 30,
            'max_users' => 5,
            'is_active' => true,
            'sort_order' => 2,
        ], $overrides));
    }

    private function actingUser(): User
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        return $user;
    }

    public function test_subscription_endpoint_returns_trial_status_with_payment_info(): void
    {
        $trialPlan = $this->makePlan([
            'name' => 'Deneme', 'slug' => 'deneme', 'price_minor' => 0,
            'price_yearly_minor' => 0, 'duration_days' => 14, 'sort_order' => 0,
        ]);
        Setting::set('payment_iban', 'TR11 0000 0000 0000 0000 0000 01');
        Setting::set('payment_account_holder', 'Cicibyte Teknoloji');

        $user = $this->actingUser();
        $user->company->update([
            'plan_id' => $trialPlan->id,
            'subscription_expires_at' => now()->addDays(10),
        ]);

        $this->getJson('/api/v1/subscription')
            ->assertOk()
            ->assertJsonPath('data.is_trial', true)
            ->assertJsonPath('data.has_active_subscription', true)
            ->assertJsonPath('data.plan.slug', 'deneme')
            ->assertJsonPath('data.payment_info.iban', 'TR11 0000 0000 0000 0000 0000 01')
            ->assertJsonPath('data.payment_info.account_holder', 'Cicibyte Teknoloji');

        $days = $this->getJson('/api/v1/subscription')->json('data.days_remaining');
        $this->assertGreaterThanOrEqual(9, $days);
        $this->assertLessThanOrEqual(10, $days);
    }

    public function test_expired_subscription_reports_zero_days_and_inactive(): void
    {
        $plan = $this->makePlan();
        $user = $this->actingUser();
        $user->company->update([
            'plan_id' => $plan->id,
            'subscription_expires_at' => now()->subDays(3),
        ]);

        $this->getJson('/api/v1/subscription')
            ->assertOk()
            ->assertJsonPath('data.is_trial', false)
            ->assertJsonPath('data.has_active_subscription', false)
            ->assertJsonPath('data.days_remaining', 0);
    }

    public function test_plans_endpoint_excludes_trial_and_inactive_plans(): void
    {
        $this->makePlan(['name' => 'Deneme', 'slug' => 'deneme', 'sort_order' => 0]);
        $this->makePlan();
        $this->makePlan(['name' => 'Eski Paket', 'slug' => 'eski', 'is_active' => false, 'sort_order' => 9]);

        $this->actingUser();

        $response = $this->getJson('/api/v1/plans')->assertOk();

        $slugs = collect($response->json('data'))->pluck('slug');
        $this->assertEquals(['profesyonel'], $slugs->all());
        $response->assertJsonPath('data.0.yearly_savings_percent', 8)
            ->assertJsonPath('data.0.audience', '3-5 kişilik ekipler için')
            ->assertJsonPath('data.0.features', ['Dijital imza', 'cari hesap takibi']);
    }

    public function test_payment_request_can_be_created_and_notifies_admins(): void
    {
        Notification::fake();

        AdminUser::create([
            'full_name' => 'Admin', 'email' => 'admin@test.dev',
            'password' => Hash::make('secret-password'),
        ]);
        $plan = $this->makePlan();
        $user = $this->actingUser();

        $this->postJson('/api/v1/subscription/payment-requests', [
            'plan_id' => $plan->id,
            'billing_period' => 'YEARLY',
            'claimed_amount_minor' => 1100000,
            'customer_note' => 'Dekont no: 12345',
        ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'PENDING')
            ->assertJsonPath('data.plan.name', 'Profesyonel')
            ->assertJsonPath('data.requested_duration', 'YEARLY');

        $this->assertDatabaseHas('payment_requests', [
            'company_id' => $user->company_id,
            'requested_by_user_id' => $user->id,
            'status' => 'PENDING',
        ]);

        Notification::assertSentTo(
            AdminUser::query()->where('email', 'admin@test.dev')->first(),
            NewPaymentRequestReceived::class,
        );
    }

    public function test_payment_request_rejects_invalid_billing_period_and_inactive_plan(): void
    {
        $inactive = $this->makePlan(['slug' => 'pasif', 'is_active' => false]);
        $this->actingUser();

        $this->postJson('/api/v1/subscription/payment-requests', [
            'plan_id' => $inactive->id,
            'billing_period' => 'WEEKLY',
        ])->assertUnprocessable()->assertJsonValidationErrors(['plan_id', 'billing_period']);
    }

    public function test_payment_request_list_is_scoped_to_own_company(): void
    {
        $plan = $this->makePlan();
        $user = $this->actingUser();
        $otherCompany = Company::factory()->create();

        PaymentRequest::create([
            'company_id' => $user->company_id, 'requested_by_user_id' => $user->id,
            'plan_id' => $plan->id, 'requested_duration' => 'MONTHLY', 'status' => 'PENDING',
        ]);
        PaymentRequest::create([
            'company_id' => $otherCompany->id,
            'requested_by_user_id' => User::factory()->create(['company_id' => $otherCompany->id])->id,
            'plan_id' => $plan->id, 'requested_duration' => 'MONTHLY', 'status' => 'PENDING',
        ]);

        $response = $this->getJson('/api/v1/subscription/payment-requests')->assertOk();

        $this->assertCount(1, $response->json('data'));
    }
}
