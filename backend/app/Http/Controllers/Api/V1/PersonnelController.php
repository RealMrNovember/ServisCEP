<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Personnel\StorePersonnelRequest;
use App\Http\Requests\Personnel\UpdatePersonnelRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\AuditLogService;
use App\Support\RolePermissions;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Hash;

/**
 * Personel yönetimi — bkz. docs/09 § 1 Yetkilendirme (Roller).
 *
 * Yalnızca işletme sahibi (PERSONNEL_MANAGE) erişebilir. Kritik
 * güvenlikler:
 *  - Kullanıcı kendi rolünü değiştiremez ve kendini silemez (kilitlenme
 *    riski).
 *  - Son OWNER hiçbir şekilde silinemez/rolü düşürülemez — aksi halde
 *    şirket yönetilemez hâle gelirdi.
 *  - Paket kullanıcı limiti (Plan::max_users) burada uygulanır; alan
 *    vardı ama hiçbir yerde kontrol edilmiyordu.
 */
class PersonnelController extends Controller
{
    public function __construct(private readonly AuditLogService $auditLogService)
    {
    }

    private function authorizeManage(Request $request): User
    {
        $user = $request->user();
        abort_unless(
            $user->hasPermission(RolePermissions::PERSONNEL_MANAGE),
            403,
            'Personel yönetimi için yetkin yok.'
        );

        return $user;
    }

    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorizeManage($request);

        return UserResource::collection(
            User::where('company_id', $request->user()->company_id)
                ->orderByRaw("CASE WHEN role = 'OWNER' THEN 0 ELSE 1 END")
                ->orderBy('full_name')
                ->get()
        );
    }

    public function store(StorePersonnelRequest $request): JsonResponse
    {
        $owner = $this->authorizeManage($request);
        $company = $owner->company()->with('plan')->first();

        $maxUsers = $company->plan?->max_users;
        if ($maxUsers !== null) {
            $current = User::where('company_id', $company->id)->count();
            if ($current >= $maxUsers) {
                abort(422, "Paketin {$maxUsers} kullanıcıya kadar izin veriyor. Daha fazlası için paketini yükseltmelisin.");
            }
        }

        $user = User::create([
            'company_id' => $company->id,
            'full_name' => $request->string('full_name')->toString(),
            'email' => $request->string('email')->toString(),
            'phone' => $request->input('phone'),
            'role' => $request->string('role')->toString(),
            // Hash'leme burada AÇIKÇA yapılır: User modelinde 'password'
            // cast'i yok (bkz. B3'teki çifte hash'leme regresyonu).
            'password' => Hash::make($request->string('password')->toString()),
        ]);

        $this->auditLogService->record(
            $owner, 'personnel.created', 'user', $user->id,
            "Personel eklendi: {$user->full_name} ({$user->role})"
        );

        return (new UserResource($user))->response()->setStatusCode(201);
    }

    public function update(UpdatePersonnelRequest $request, User $personnel): JsonResponse
    {
        $owner = $this->authorizeManage($request);
        $this->assertSameCompany($owner, $personnel);

        abort_if(
            $personnel->id === $owner->id,
            422,
            'Kendi rolünü değiştiremezsin.'
        );

        $data = $request->validated();

        if (isset($data['role']) && $personnel->role === RolePermissions::OWNER) {
            abort_if($this->ownerCount($owner) <= 1, 422, 'Son işletme sahibinin rolü değiştirilemez.');
        }

        $personnel->update($data);

        $this->auditLogService->record(
            $owner, 'personnel.updated', 'user', $personnel->id,
            "Personel güncellendi: {$personnel->full_name} ({$personnel->role})"
        );

        return (new UserResource($personnel->refresh()))->response();
    }

    public function destroy(Request $request, User $personnel): Response
    {
        $owner = $this->authorizeManage($request);
        $this->assertSameCompany($owner, $personnel);

        abort_if($personnel->id === $owner->id, 422, 'Kendini silemezsin.');
        abort_if(
            $personnel->role === RolePermissions::OWNER && $this->ownerCount($owner) <= 1,
            422,
            'Son işletme sahibi silinemez.'
        );

        $name = $personnel->full_name;
        // Cihaz kayıtları ve oturum jetonları cascade ile temizlenir
        // (device_tokens.user_id -> cascadeOnDelete); silinen personelin
        // telefonuna bildirim gitmeye devam etmemeli.
        $personnel->tokens()->delete();
        $personnel->delete();

        $this->auditLogService->record(
            $owner, 'personnel.deleted', 'user', null,
            "Personel silindi: {$name}"
        );

        return response()->noContent();
    }

    private function assertSameCompany(User $owner, User $personnel): void
    {
        abort_unless($owner->company_id === $personnel->company_id, 404);
    }

    private function ownerCount(User $owner): int
    {
        return User::where('company_id', $owner->company_id)
            ->where('role', RolePermissions::OWNER)
            ->count();
    }
}
