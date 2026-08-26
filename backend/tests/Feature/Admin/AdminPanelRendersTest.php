<?php

declare(strict_types=1);

namespace Tests\Feature\Admin;

use App\Filament\Resources\Companies\Pages\ListCompanies;
use App\Filament\Resources\Users\Pages\ListUsers;
use App\Models\AdminUser;
use App\Models\Company;
use App\Models\PaymentRequest;
use App\Models\Plan;
use App\Models\User;
use App\Notifications\SubscriptionChanged;
use Filament\Facades\Filament;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Livewire\Livewire;
use Tests\TestCase;

/**
 * Admin panel sayfalarının GERÇEKTEN render olduğunu doğrular.
 *
 * Neden var: 2026-08-25'te abonelik yönetimi aksiyonu, yanlış ad
 * alanından import edilen bir bileşen (Placeholder) yüzünden kırıldı.
 * Backend'in 165 testi yeşildi ama hiçbiri Filament sayfalarını
 * render etmediği için hata ancak kullanıcı panele girince ortaya çıktı.
 * Bu testler o boşluğu kapatır: sayfa açılışı ve aksiyon formunun
 * kurulması artık CI'da sınanıyor.
 */
class AdminPanelRendersTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $admin = AdminUser::create([
            'full_name' => 'Süper Admin',
            'email' => 'admin@ornek.test',
            'password' => bcrypt('sifre1234'),
        ]);

        $this->actingAs($admin, 'admin');
        Filament::setCurrentPanel('admin');
    }

    public function test_companies_list_page_renders(): void
    {
        User::factory()->create();

        Livewire::test(ListCompanies::class)->assertSuccessful();
    }

    public function test_users_list_page_renders(): void
    {
        User::factory()->create();

        Livewire::test(ListUsers::class)->assertSuccessful();
    }

    public function test_subscription_action_form_can_be_opened(): void
    {
        $user = User::factory()->create();
        $company = Company::findOrFail($user->company_id);

        // Aksiyonun form şeması mount anında kurulur — bozuk bir bileşen
        // ya da yanlış import tam burada patlar.
        Livewire::test(ListCompanies::class)
            ->mountTableAction('extend', $company)
            ->assertSuccessful();
    }

    public function test_subscription_action_extends_and_assigns_plan(): void
    {
        $user = User::factory()->create();
        $company = Company::findOrFail($user->company_id);
        $company->update(['subscription_expires_at' => now()->addDays(5)]);

        $plan = Plan::create([
            'name' => 'Profesyonel', 'slug' => 'profesyonel',
            'price_minor' => 50000, 'price_yearly_minor' => 500000,
            'is_active' => true, 'sort_order' => 1,
        ]);

        Livewire::test(ListCompanies::class)
            ->callTableAction('extend', $company, [
                'mode' => 'add',
                'months' => '3',
                'days' => 0,
                'plan_id' => $plan->id,
                'note' => 'Havale onaylandı',
            ])
            ->assertHasNoTableActionErrors();

        $company->refresh();

        // Mevcut süre gelecekteydi: üzerine eklenmeli (erken yenileme
        // hak kaybettirmez).
        $this->assertSame(
            now()->addDays(5)->addMonths(3)->toDateString(),
            $company->subscription_expires_at->toDateString(),
        );
        $this->assertSame($plan->id, $company->plan_id);
        $this->assertTrue($company->is_active);
        $this->assertSame('Havale onaylandı', $company->admin_note);

        // Süper-admin işlemi iz bırakmalı.
        $this->assertDatabaseHas('audit_logs', [
            'company_id' => $company->id,
            'action' => 'subscription.extended',
        ]);
    }

    public function test_subscription_action_can_set_an_exact_end_date(): void
    {
        $user = User::factory()->create();
        $company = Company::findOrFail($user->company_id);
        $target = now()->addMonths(8)->startOfDay();

        Livewire::test(ListCompanies::class)
            ->callTableAction('extend', $company, [
                'mode' => 'exact',
                'exact_date' => $target->toDateString(),
            ])
            ->assertHasNoTableActionErrors();

        $this->assertSame(
            $target->toDateString(),
            $company->refresh()->subscription_expires_at->toDateString(),
        );
    }

    public function test_customer_is_always_notified_when_subscription_changes(): void
    {
        Notification::fake();

        $user = User::factory()->create();
        $company = Company::findOrFail($user->company_id);

        Livewire::test(ListCompanies::class)
            ->callTableAction('extend', $company, [
                'mode' => 'add',
                'months' => '1',
                'days' => 0,
            ])
            ->assertHasNoTableActionErrors();

        // Müşteri ödemesini yaptıktan sonra onayı bekliyor — bildirim
        // KAPATILAMAZ, her değişiklikte gitmek zorunda (kullanıcı kararı).
        Notification::assertSentTo(
            $user,
            SubscriptionChanged::class,
        );
    }

    public function test_payment_approval_notifies_the_customer(): void
    {
        Notification::fake();

        $user = User::factory()->create();
        $company = Company::findOrFail($user->company_id);
        $plan = Plan::create([
            'name' => 'Profesyonel', 'slug' => 'pro',
            'price_minor' => 1, 'price_yearly_minor' => 1,
            'is_active' => true, 'sort_order' => 1,
        ]);

        $request = PaymentRequest::create([
            'company_id' => $company->id,
            'requested_by_user_id' => $user->id,
            'plan_id' => $plan->id,
            'requested_duration' => 'MONTHLY',
            'status' => 'PENDING',
        ]);

        $request->approve('MONTHLY', AdminUser::first());

        Notification::assertSentTo(
            $user,
            SubscriptionChanged::class,
        );
    }

    public function test_expired_company_is_reactivated_from_today_not_from_past(): void
    {
        $user = User::factory()->create();
        $company = Company::findOrFail($user->company_id);
        $company->update([
            'subscription_expires_at' => now()->subMonths(2),
            'is_active' => false,
        ]);

        Livewire::test(ListCompanies::class)
            ->callTableAction('extend', $company, [
                'mode' => 'add',
                'months' => '1',
                'days' => 0,
            ])
            ->assertHasNoTableActionErrors();

        $company->refresh();

        // Süresi dolmuşsa bugünden başlar — geçmişe eklenirse abonelik
        // hâlâ dolmuş görünürdü.
        $this->assertSame(
            now()->addMonth()->toDateString(),
            $company->subscription_expires_at->toDateString(),
        );
        $this->assertTrue($company->is_active);
    }
}
