<?php

declare(strict_types=1);

namespace Tests\Feature\Subscription;

use App\Models\Company;
use App\Models\Plan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

/**
 * Abonelik yaptırımı — süresi dolan şirket veri uçlarına erişemez (402)
 * ama kimlik/abonelik uçları açık kalır (yenileme yapabilmeli). Bkz.
 * EnsureSubscriptionIsActive + EnsureAppPanelSubscriptionIsActive.
 */
class SubscriptionEnforcementTest extends TestCase
{
    use RefreshDatabase;

    private function expiredUser(): User
    {
        $user = User::factory()->create();
        Company::whereKey($user->company_id)->update([
            'subscription_expires_at' => Carbon::now()->subDay(),
        ]);

        return $user->refresh();
    }

    public function test_expired_company_gets_402_on_data_endpoints(): void
    {
        $user = $this->expiredUser();
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->getJson('/api/v1/customers')
            ->assertStatus(402)
            ->assertJsonPath('code', 'SUBSCRIPTION_EXPIRED');

        $this->postJson('/api/v1/jobs', [])->assertStatus(402);
        $this->getJson('/api/v1/quotes')->assertStatus(402);
    }

    public function test_expired_company_can_still_see_identity_and_renew(): void
    {
        $user = $this->expiredUser();
        $this->withToken($user->createToken('test')->plainTextToken);

        // Kimlik + abonelik durumu görünür kalmalı.
        $this->getJson('/api/v1/auth/me')->assertOk();
        $this->getJson('/api/v1/subscription')
            ->assertOk()
            ->assertJsonPath('data.has_active_subscription', false);
        $this->getJson('/api/v1/plans')->assertOk();

        // Ödeme bildirimi (yenileme yolu) çalışmalı.
        $plan = Plan::create([
            'name' => 'Başlangıç', 'slug' => 'baslangic',
            'price_minor' => 50000, 'price_yearly_minor' => 500000,
            'is_active' => true, 'sort_order' => 1,
        ]);
        $this->postJson('/api/v1/subscription/payment-requests', [
            'plan_id' => $plan->id,
            'billing_period' => 'MONTHLY',
        ])->assertCreated();

        // Çıkış da her zaman mümkün olmalı.
        $this->postJson('/api/v1/auth/logout')->assertOk();
    }

    public function test_active_company_is_unaffected(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->getJson('/api/v1/customers')->assertOk();
    }

    public function test_manually_suspended_company_is_blocked_too(): void
    {
        $user = User::factory()->create();
        Company::whereKey($user->company_id)->update(['is_active' => false]);
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->getJson('/api/v1/customers')
            ->assertStatus(402)
            ->assertJsonPath('code', 'SUBSCRIPTION_EXPIRED');
    }

    public function test_app_panel_redirects_expired_company_to_subscription_page(): void
    {
        $user = $this->expiredUser();

        $this->actingAs($user)
            ->get('/panel')
            ->assertRedirect(route('filament.app.pages.subscription'));

        // Abonelik sayfasının kendisi açılabilir (redirect döngüsü yok).
        $this->actingAs($user)
            ->get(route('filament.app.pages.subscription'))
            ->assertOk();
    }
}
