<?php

declare(strict_types=1);

namespace Tests\Feature\Personnel;

use App\Models\Customer;
use App\Models\User;
use App\Support\RolePermissions;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Rol bazlı yetkilendirmenin GERÇEKTEN uygulandığını doğrular.
 *
 * Kritik iş kuralı: saha teknisyeni işletmenin finansal verilerini
 * göremez. Bu test o kuralın sessizce bozulmasını engeller.
 */
class RolePermissionTest extends TestCase
{
    use RefreshDatabase;

    private function actingAsRole(string $role): User
    {
        $user = User::factory()->create(['role' => $role]);
        $this->app['auth']->forgetGuards();
        $this->withToken($user->createToken('test')->plainTextToken);

        return $user;
    }

    public function test_technician_cannot_see_company_finances(): void
    {
        $this->actingAsRole(RolePermissions::TECHNICIAN);

        $this->getJson('/api/v1/income-entries')->assertForbidden();
        $this->getJson('/api/v1/expense-entries')->assertForbidden();
        $this->getJson('/api/v1/ledger-entries')->assertForbidden();
    }

    public function test_technician_can_do_field_work(): void
    {
        $user = $this->actingAsRole(RolePermissions::TECHNICIAN);

        $this->getJson('/api/v1/customers')->assertOk();
        $this->getJson('/api/v1/jobs')->assertOk();
        $this->postJson('/api/v1/customers', [
            'code' => 'CUS-1', 'contact_name' => 'Saha Müşterisi', 'type' => 'BIREYSEL',
        ])->assertCreated();
    }

    public function test_technician_cannot_delete_customers(): void
    {
        $user = $this->actingAsRole(RolePermissions::TECHNICIAN);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->deleteJson("/api/v1/customers/{$customer->id}")->assertForbidden();
    }

    public function test_accounting_sees_finance_but_cannot_manage_jobs(): void
    {
        $user = $this->actingAsRole(RolePermissions::ACCOUNTING);

        $this->getJson('/api/v1/income-entries')->assertOk();
        $this->getJson('/api/v1/ledger-entries')->assertOk();

        // NOT: Laravel FormRequest doğrulamasını yetkilendirmeden ÖNCE
        // çalıştırır; bu yüzden geçerli bir gövde gönderilmeli, aksi halde
        // 403 yerine 422 alınır ve yetki yolu hiç sınanmamış olur.
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);
        $this->postJson('/api/v1/jobs', [
            'code' => 'SRV-1',
            'customer_id' => $customer->id,
            'title' => 'Muhasebe iş açamaz',
            'priority' => 'NORMAL',
            'status' => 'TALEP',
        ])->assertForbidden();
    }

    public function test_viewer_is_read_only(): void
    {
        $this->actingAsRole(RolePermissions::VIEWER);

        $this->getJson('/api/v1/customers')->assertOk();
        $this->postJson('/api/v1/customers', [
            'code' => 'CUS-1', 'contact_name' => 'X', 'type' => 'BIREYSEL',
        ])->assertForbidden();
        $this->getJson('/api/v1/income-entries')->assertForbidden();
    }

    public function test_only_owner_reaches_owner_only_areas(): void
    {
        $this->actingAsRole(RolePermissions::ADMIN);
        $this->getJson('/api/v1/personnel')->assertForbidden();
        $this->getJson('/api/v1/audit-logs')->assertForbidden();
        $this->putJson('/api/v1/company', ['name' => 'X'])->assertForbidden();

        $this->actingAsRole(RolePermissions::OWNER);
        $this->getJson('/api/v1/personnel')->assertOk();
        $this->getJson('/api/v1/audit-logs')->assertOk();
        $this->putJson('/api/v1/company', ['name' => 'X'])->assertOk();
    }

    public function test_admin_can_manage_finance_but_not_adjust_ledger(): void
    {
        $user = $this->actingAsRole(RolePermissions::ADMIN);
        $customer = Customer::factory()->create(['company_id' => $user->company_id]);

        $this->getJson('/api/v1/income-entries')->assertOk();

        // Cari manuel düzeltme denetim açısından hassas — OWNER/ACCOUNTING'e özel.
        $this->postJson("/api/v1/customers/{$customer->id}/ledger/adjustments", [
            'type' => 'DEBIT', 'amount_minor' => 100, 'description' => 'Deneme',
        ])->assertForbidden();
    }

    public function test_matrix_has_no_unknown_role_leak(): void
    {
        // Tanımsız bir rol hiçbir şeye yetkili olmamalı (fail-closed).
        $this->assertFalse(RolePermissions::allows('UYDURMA_ROL', RolePermissions::CUSTOMERS_VIEW));
        $this->assertFalse(RolePermissions::allows(null, RolePermissions::CUSTOMERS_VIEW));
    }
}
