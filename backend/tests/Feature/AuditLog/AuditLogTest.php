<?php

declare(strict_types=1);

namespace Tests\Feature\AuditLog;

use App\Models\Customer;
use App\Models\Job;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Bkz. docs/09 § 5 Audit Log — audit gerektiren kritik işlemler: belge
 * oluşturma, tahsilat, müşteri değişikliği, cari hesap manuel düzeltmesi.
 */
class AuditLogTest extends TestCase
{
    use RefreshDatabase;

    public function test_creating_a_customer_writes_an_audit_log_entry(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->postJson('/api/v1/customers', ['code' => 'M-1', 'contact_name' => 'Test', 'type' => 'BIREYSEL'])
            ->assertCreated();

        $this->assertDatabaseHas('audit_logs', [
            'company_id' => $user->company_id,
            'user_id' => $user->id,
            'action' => 'customer.created',
            'subject_type' => 'customer',
        ]);
    }

    public function test_recording_a_payment_writes_an_audit_log_entry(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->postJson("/api/v1/customers/{$customer->id}/payments", ['amount_minor' => 10000, 'method' => 'Nakit'])
            ->assertCreated();

        $this->assertDatabaseHas('audit_logs', [
            'company_id' => $user->company_id,
            'action' => 'payment.recorded',
            'subject_type' => 'payment',
        ]);
    }

    public function test_completing_a_job_writes_an_audit_log_entry(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $job = Job::factory()->create(['company_id' => $user->company_id, 'status' => 'DEVAM_EDIYOR']);

        $this->putJson("/api/v1/jobs/{$job->id}", ['base_version' => 1, 'status' => 'TAMAMLANDI', 'actual_price_minor' => 50000])
            ->assertOk();

        $this->assertDatabaseHas('audit_logs', [
            'company_id' => $user->company_id,
            'action' => 'job.completed',
            'subject_type' => 'job',
            'subject_id' => $job->id,
        ]);
    }

    public function test_a_manual_ledger_adjustment_writes_an_audit_log_entry(): void
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->postJson("/api/v1/customers/{$customer->id}/ledger/adjustments", [
            'type' => 'DEBIT', 'amount_minor' => 5000, 'description' => 'Test',
        ])->assertCreated();

        $this->assertDatabaseHas('audit_logs', [
            'company_id' => $user->company_id,
            'action' => 'ledger.manual_adjustment',
        ]);
    }

    public function test_only_owner_can_view_audit_logs(): void
    {
        $user = User::factory()->create(['role' => 'VIEWER']);
        $this->withToken($user->createToken('test')->plainTextToken);

        $this->getJson('/api/v1/audit-logs')->assertForbidden();
    }

    public function test_owner_can_view_only_their_companys_audit_logs(): void
    {
        // Not: Sanctum'un RequestGuard'ı, aynı test metodu içinde farklı
        // token'lara geçerken çözümlenmiş kullanıcıyı önbellekte tutar
        // (bkz. AuthenticatedRequestsTest::test_logout_revokes... ile aynı
        // bilinen davranış) — her token değişiminden sonra guard'ı elle
        // temizlemek gerekir, yoksa tüm istekler ilk kullanıcıyla kimliği
        // doğrulanmış gibi işlenir.
        $userA = User::factory()->create();
        $userB = User::factory()->create();

        $this->withToken($userA->createToken('test')->plainTextToken);
        $this->postJson('/api/v1/customers', ['code' => 'M-1', 'contact_name' => 'A', 'type' => 'BIREYSEL'])
            ->assertCreated();
        $this->app['auth']->forgetGuards();

        $this->withToken($userB->createToken('test')->plainTextToken);
        $this->postJson('/api/v1/customers', ['code' => 'M-2', 'contact_name' => 'B', 'type' => 'BIREYSEL'])
            ->assertCreated();
        $this->app['auth']->forgetGuards();

        $this->withToken($userA->createToken('test2')->plainTextToken)
            ->getJson('/api/v1/audit-logs')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.description', 'Müşteri oluşturuldu: A');
    }
}
