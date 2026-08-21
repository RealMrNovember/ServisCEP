<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\AuditLogResource;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class AuditLogController extends Controller
{
    /**
     * Denetim kaydı hassas bir bilgidir — yalnızca OWNER görebilir
     * (bkz. docs/09 § 1 Yetkilendirme, aynı kural cari hesap manuel
     * düzeltmesiyle tutarlı — bkz. CustomerPolicy::recordLedgerAdjustment).
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        Gate::authorize('viewAuditLogs', AuditLog::class);

        $logs = AuditLog::query()
            ->when($request->filled('subject_type'), fn ($query) => $query->where('subject_type', $request->input('subject_type')))
            ->latest('created_at')
            ->paginate((int) $request->input('per_page', 30));

        return AuditLogResource::collection($logs);
    }
}
