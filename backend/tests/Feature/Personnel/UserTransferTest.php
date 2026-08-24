<?php

declare(strict_types=1);

namespace Tests\Feature\Personnel;

use App\Models\AdminUser;
use App\Models\Company;
use App\Models\Customer;
use App\Models\DeviceToken;
use App\Models\User;
use App\Services\UserTransferService;
use App\Support\RolePermissions;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

/**
 * "Yanlışlıkla üye oldum" senaryosu: kişi kendi şirketini açmış, sonra
 * çalıştığı firma onu ekibe almak istiyor. E-posta global benzersiz
 * olduğu için firma sahibi ekleyemez; hesap taşınmalıdır.
 */
class UserTransferTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): AdminUser
    {
        return AdminUser::create([
            'full_name' => 'Süper Admin',
            'email' => 'admin@ornek.test',
            'password' => bcrypt('sifre1234'),
        ]);
    }

    public function test_moves_solo_user_into_real_company_and_cleans_up_empty_one(): void
    {
        $stray = User::factory()->create(['role' => RolePermissions::OWNER]);
        $strayCompanyId = $stray->company_id;
        $target = User::factory()->create(['role' => RolePermissions::OWNER]);

        app(UserTransferService::class)->transfer(
            $stray,
            $target->company_id,
            RolePermissions::TECHNICIAN,
            $this->admin(),
            deleteEmptyOrigin: true,
        );

        $stray->refresh();
        $this->assertSame($target->company_id, $stray->company_id);
        $this->assertSame(RolePermissions::TECHNICIAN, $stray->role);
        $this->assertDatabaseMissing('companies', ['id' => $strayCompanyId]);
    }

    public function test_does_not_delete_origin_company_that_has_real_data(): void
    {
        $stray = User::factory()->create(['role' => RolePermissions::OWNER]);
        $strayCompanyId = $stray->company_id;
        Customer::factory()->create(['company_id' => $strayCompanyId]);
        $target = User::factory()->create(['role' => RolePermissions::OWNER]);

        app(UserTransferService::class)->transfer(
            $stray,
            $target->company_id,
            RolePermissions::TECHNICIAN,
            $this->admin(),
            deleteEmptyOrigin: true,
        );

        // Gerçek verisi olan şirket ASLA otomatik silinmez.
        $this->assertDatabaseHas('companies', ['id' => $strayCompanyId]);
    }

    public function test_cannot_orphan_a_company_that_still_has_other_users(): void
    {
        $owner = User::factory()->create(['role' => RolePermissions::OWNER]);
        User::factory()->create([
            'company_id' => $owner->company_id,
            'role' => RolePermissions::TECHNICIAN,
        ]);
        $target = User::factory()->create(['role' => RolePermissions::OWNER]);

        $this->expectException(ValidationException::class);

        app(UserTransferService::class)->transfer(
            $owner,
            $target->company_id,
            RolePermissions::TECHNICIAN,
            $this->admin(),
        );
    }

    public function test_transfer_revokes_sessions_and_push_registrations(): void
    {
        $stray = User::factory()->create(['role' => RolePermissions::OWNER]);
        $stray->createToken('phone');
        DeviceToken::create([
            'user_id' => $stray->id,
            'company_id' => $stray->company_id,
            'token' => 'device-1',
            'platform' => 'android',
        ]);
        $target = User::factory()->create(['role' => RolePermissions::OWNER]);

        app(UserTransferService::class)->transfer(
            $stray,
            $target->company_id,
            RolePermissions::TECHNICIAN,
            $this->admin(),
        );

        // Eski oturumla devam etmek yanlış şirketin verisini gösterirdi.
        $this->assertSame(0, $stray->tokens()->count());
        $this->assertDatabaseMissing('device_tokens', ['token' => 'device-1']);
    }

    public function test_rejects_transfer_into_same_company(): void
    {
        $user = User::factory()->create();

        $this->expectException(ValidationException::class);

        app(UserTransferService::class)->transfer(
            $user,
            $user->company_id,
            RolePermissions::TECHNICIAN,
            $this->admin(),
        );
    }

    public function test_owner_gets_actionable_message_when_email_belongs_elsewhere(): void
    {
        $owner = User::factory()->create(['role' => RolePermissions::OWNER]);
        $stray = User::factory()->create();
        $this->withToken($owner->createToken('test')->plainTextToken);

        $response = $this->postJson('/api/v1/personnel', [
            'full_name' => 'Zaten Var',
            'email' => $stray->email,
            'role' => RolePermissions::TECHNICIAN,
            'password' => 'GucluParola1',
        ])->assertUnprocessable();

        $this->assertStringContainsString(
            'destekle iletişime geç',
            $response->json('errors.email.0'),
        );
    }

    public function test_owner_is_told_when_person_is_already_in_the_team(): void
    {
        $owner = User::factory()->create(['role' => RolePermissions::OWNER]);
        $mate = User::factory()->create([
            'company_id' => $owner->company_id,
            'role' => RolePermissions::TECHNICIAN,
        ]);
        $this->withToken($owner->createToken('test')->plainTextToken);

        $response = $this->postJson('/api/v1/personnel', [
            'full_name' => 'Aynı Kişi',
            'email' => $mate->email,
            'role' => RolePermissions::TECHNICIAN,
            'password' => 'GucluParola1',
        ])->assertUnprocessable();

        $this->assertSame('Bu kişi zaten ekibinde.', $response->json('errors.email.0'));
    }
}
