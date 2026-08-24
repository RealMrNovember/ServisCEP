<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\CustomerLedgerEntryResource;
use App\Models\CustomerLedgerEntry;
use App\Support\RolePermissions;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * Şirket geneli cari hesap hareketleri — mobil senkronun "pull" ucu.
 *
 * Müşteri bazlı `/customers/{id}/ledger` ucu ekran içindir (sayfalı,
 * bakiyeli). Bu uç ise senkron içindir: mobil, sunucudaki hareketlerin
 * TAMAMINI çekip yerel kopyasını hizalar.
 *
 * Neden gerekliydi: mobil ve backend, iş tamamlama/tahsilat sonrası
 * kendi cari kayıtlarını BİRBİRİNDEN BAĞIMSIZ oluşturuyordu. İkisi aynı
 * kuralı uyguladığı için sonuç genelde aynıydı, ama tek doğruluk kaynağı
 * yoktu — bakiyeler sessizce ayrışabilirdi. Artık sunucu tek kaynaktır;
 * mobil yerelde iyimser kayıt tutar, pull sırasında sunucununkiyle
 * değiştirir (bkz. mobile SyncService._pullLedgerEntries).
 */
class LedgerEntryController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        abort_unless(
            $request->user()->hasPermission(RolePermissions::FINANCE_VIEW),
            403,
            'Cari hesap için yetkin yok.'
        );

        $entries = CustomerLedgerEntry::query()
            ->when($request->filled('customer_id'), fn ($q) => $q->where('customer_id', $request->input('customer_id')))
            ->orderBy('entry_date')
            ->paginate((int) $request->input('per_page', 100));

        return CustomerLedgerEntryResource::collection($entries);
    }
}
