<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Company\UpdateCompanyRequest;
use App\Http\Resources\CompanyResource;
use App\Services\AuditLogService;
use App\Support\RolePermissions;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Şirket ayarları — web panelindeki şirket profili alanlarının mobil
 * karşılığı. Kullanıcı yalnızca KENDİ şirketini görüp düzenleyebilir:
 * şirket, oturumdan türetilir, istekten gelen bir id ile DEĞİL.
 */
class CompanyController extends Controller
{
    public function __construct(private readonly AuditLogService $auditLogService)
    {
    }

    public function show(Request $request): CompanyResource
    {
        return new CompanyResource($request->user()->company);
    }

    public function update(UpdateCompanyRequest $request): JsonResponse
    {
        $user = $request->user();

        // Yalnızca işletme sahibi şirket ayarlarını değiştirebilir;
        // diğer roller görüntüler (bkz. RolePermissions matrisi).
        abort_unless(
            $user->hasPermission(RolePermissions::COMPANY_MANAGE),
            403,
            'Bu işlem için yetkin yok.'
        );

        $company = $user->company;
        $company->update($request->validated());

        $this->auditLogService->record(
            $user, 'company.updated', 'company', $company->id,
            "Şirket ayarları güncellendi: {$company->name}"
        );

        return (new CompanyResource($company->refresh()))->response();
    }
}
