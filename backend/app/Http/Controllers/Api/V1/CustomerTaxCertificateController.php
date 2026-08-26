<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Customer\StoreCustomerTaxCertificateRequest;
use App\Http\Resources\CustomerResource;
use App\Models\Customer;
use App\Services\AuditLogService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Müşteri vergi levhası — web panelindeki `tax_certificate_path`
 * FileUpload alanının mobil karşılığı. Dosya `local` disk'te
 * (storage/app/private) `tax-certificates/{company_id}` altında tutulur,
 * asla public bir yoldan servis edilmez (bkz. docs/09 § Dosya Güvenliği).
 */
class CustomerTaxCertificateController extends Controller
{
    public function __construct(private readonly AuditLogService $auditLogService) {}

    public function store(StoreCustomerTaxCertificateRequest $request, Customer $customer): JsonResponse
    {
        Gate::authorize('update', $customer);

        // Aynı müşteri için ikinci bir yükleme öncekinin yerine geçer —
        // yetim dosya bırakmamak için eskisi silinir.
        if ($customer->tax_certificate_path) {
            Storage::disk('local')->delete($customer->tax_certificate_path);
        }

        $path = $request->file('file')->store(
            'tax-certificates/'.$customer->company_id,
            'local'
        );

        $customer->update(['tax_certificate_path' => $path]);

        $this->auditLogService->record(
            $request->user(), 'customer.tax_certificate_uploaded', 'customer', $customer->id,
            "Vergi levhası yüklendi: {$customer->display_name}"
        );

        return (new CustomerResource($customer))->response()->setStatusCode(201);
    }

    public function download(Customer $customer): StreamedResponse
    {
        Gate::authorize('view', $customer);
        abort_unless((bool) $customer->tax_certificate_path, 404);

        return Storage::disk('local')->response($customer->tax_certificate_path);
    }

    /**
     * İmzalı, süreli erişim linki — `signed` middleware'i tarafından
     * korunur (bkz. docs/09 § Dosya Güvenliği, madde 2).
     */
    public function signedDownload(Customer $customer): StreamedResponse
    {
        abort_unless((bool) $customer->tax_certificate_path, 404);

        return Storage::disk('local')->response($customer->tax_certificate_path);
    }

    public function destroy(Request $request, Customer $customer): JsonResponse
    {
        Gate::authorize('update', $customer);
        abort_unless((bool) $customer->tax_certificate_path, 404);

        Storage::disk('local')->delete($customer->tax_certificate_path);
        $customer->update(['tax_certificate_path' => null]);

        $this->auditLogService->record(
            $request->user(), 'customer.tax_certificate_deleted', 'customer', $customer->id,
            "Vergi levhası silindi: {$customer->display_name}"
        );

        return (new CustomerResource($customer))->response();
    }
}
