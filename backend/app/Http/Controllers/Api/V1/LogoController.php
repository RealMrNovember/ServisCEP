<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\CompanyResource;
use App\Http\Resources\CustomerResource;
use App\Models\Customer;
use App\Support\RolePermissions;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Logo yükleme — teklif/proforma PDF'lerinin antedinde kullanılır.
 *
 * İki taraf da desteklenir: işletmenin kendi logosu (belgeyi gönderen) ve
 * müşterinin logosu (belgeyi alan). Müşteri logosu isteğe bağlıdır;
 * kurumsal alıcılara giden belgelerde iki logonun yan yana durması
 * belgeye ciddiyet katar.
 *
 * Dosyalar `local` disk'te (storage/app/private) tutulur, ham yol asla
 * JSON'a sızmaz — erişim yalnızca kimlik doğrulamalı indirme uçlarından
 * (bkz. docs/09 § Dosya Güvenliği, CustomerTaxCertificateController ile
 * aynı kalıp).
 */
class LogoController extends Controller
{
    private const RULES = ['file', 'mimes:png,jpg,jpeg,webp', 'max:4096'];

    public function storeCompanyLogo(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_unless(
            $user->hasPermission(RolePermissions::COMPANY_MANAGE),
            403,
            'Bu işlem için yetkin yok.'
        );

        $request->validate(['file' => array_merge(['required'], self::RULES)]);

        $company = $user->company;
        if ($company->logo_path) {
            Storage::disk('local')->delete($company->logo_path);
        }

        $path = $request->file('file')->store("logos/{$company->id}", 'local');
        $company->update(['logo_path' => $path]);

        return (new CompanyResource($company->refresh()))->response()->setStatusCode(201);
    }

    public function showCompanyLogo(Request $request): StreamedResponse
    {
        $company = $request->user()->company;
        abort_unless((bool) $company->logo_path, 404);

        return Storage::disk('local')->response($company->logo_path);
    }

    public function destroyCompanyLogo(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_unless($user->hasPermission(RolePermissions::COMPANY_MANAGE), 403);

        $company = $user->company;
        abort_unless((bool) $company->logo_path, 404);

        Storage::disk('local')->delete($company->logo_path);
        $company->update(['logo_path' => null]);

        return (new CompanyResource($company->refresh()))->response();
    }

    public function storeCustomerLogo(Request $request, Customer $customer): JsonResponse
    {
        Gate::authorize('update', $customer);
        $request->validate(['file' => array_merge(['required'], self::RULES)]);

        if ($customer->logo_path) {
            Storage::disk('local')->delete($customer->logo_path);
        }

        $path = $request->file('file')->store("logos/{$customer->company_id}/customers", 'local');
        $customer->update(['logo_path' => $path]);

        return (new CustomerResource($customer->refresh()))->response()->setStatusCode(201);
    }

    public function showCustomerLogo(Customer $customer): StreamedResponse
    {
        Gate::authorize('view', $customer);
        abort_unless((bool) $customer->logo_path, 404);

        return Storage::disk('local')->response($customer->logo_path);
    }

    public function destroyCustomerLogo(Customer $customer): JsonResponse
    {
        Gate::authorize('update', $customer);
        abort_unless((bool) $customer->logo_path, 404);

        Storage::disk('local')->delete($customer->logo_path);
        $customer->update(['logo_path' => null]);

        return (new CustomerResource($customer->refresh()))->response();
    }
}
