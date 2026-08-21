<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Customer\StoreLedgerAdjustmentRequest;
use App\Http\Resources\CustomerLedgerEntryResource;
use App\Models\Customer;
use App\Services\CustomerLedgerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Gate;

class CustomerLedgerController extends Controller
{
    public function __construct(private readonly CustomerLedgerService $customerLedgerService)
    {
    }

    /**
     * Kronolojik hareket listesi + güncel bakiye (bkz. docs/15 § Bakiye
     * Hesaplama — her zaman ledger'dan türetilir, cache'lenmez).
     */
    public function index(Customer $customer): JsonResponse
    {
        Gate::authorize('view', $customer);

        $entries = $customer->ledgerEntries()->latest('entry_date')->paginate(30);

        $balanceMinor = (int) $customer->ledgerEntries()
            ->selectRaw("COALESCE(SUM(CASE WHEN type = 'DEBIT' THEN amount_minor ELSE -amount_minor END), 0) as balance")
            ->value('balance');

        // Not: 'balance_minor' bilerek üst seviyede — paginator'ın kendi
        // ürettiği 'meta' anahtarının (current_page, total, ...) içine
        // gömülürse additional() onu tamamen ezer.
        return CustomerLedgerEntryResource::collection($entries)
            ->additional(['balance_minor' => $balanceMinor])
            ->response();
    }

    public function storeAdjustment(StoreLedgerAdjustmentRequest $request, Customer $customer): JsonResponse
    {
        Gate::authorize('recordLedgerAdjustment', $customer);

        $entry = $this->customerLedgerService->recordManualAdjustment(
            $request->user(),
            $customer->id,
            $request->string('type')->toString(),
            (int) $request->input('amount_minor'),
            $request->string('description')->toString(),
        );

        return (new CustomerLedgerEntryResource($entry))->response()->setStatusCode(201);
    }
}
