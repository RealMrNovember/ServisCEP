<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\AcceptsClientGeneratedId;
use App\Http\Concerns\CalculatesDocumentTotal;
use App\Http\Concerns\DetectsSyncConflicts;
use App\Http\Controllers\Controller;
use App\Http\Requests\Quote\StoreQuoteRequest;
use App\Http\Requests\Quote\UpdateQuoteRequest;
use App\Http\Resources\QuoteResource;
use App\Http\Resources\SyncConflictResource;
use App\Models\Quote;
use App\Services\AuditLogService;
use App\Services\SyncConflictService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

class QuoteController extends Controller
{
    use AcceptsClientGeneratedId;
    use CalculatesDocumentTotal;
    use DetectsSyncConflicts;

    public function __construct(
        private readonly AuditLogService $auditLogService,
        private readonly SyncConflictService $syncConflictService,
    ) {
    }

    public function index(Request $request): AnonymousResourceCollection
    {
        Gate::authorize('viewAny', Quote::class);

        $quotes = Quote::query()
            // Mobil pull, kalemleri tek istekte alsın diye eager-load (N+1 da onlenir).
            ->with('items')
            ->when($request->filled('customer_id'), fn ($query) => $query->where('customer_id', $request->input('customer_id')))
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->input('status')))
            ->latest('created_at')
            ->paginate((int) $request->input('per_page', 20));

        return QuoteResource::collection($quotes);
    }

    public function store(StoreQuoteRequest $request): JsonResponse
    {
        Gate::authorize('create', Quote::class);

        if ($existing = $this->findExistingByClientId(Quote::class, $request->input('id'))) {
            return (new QuoteResource($existing->load('items')))->response()->setStatusCode(200);
        }

        $data = $request->validated();
        $items = $data['items'];
        unset($data['items']);
        $data['total_minor'] = $this->calculateItemsTotal($items);

        $quote = DB::transaction(function () use ($data, $items) {
            $quote = Quote::create($data);

            foreach ($items as $item) {
                $quote->items()->create($item);
            }

            // status, DB'nin varsayılan değeriyle ('TASLAK') doluyor —
            // bellekteki modelde bu değer yoktur, refresh() gerekir (bkz.
            // CustomerController::store() ile aynı hata kalıbı).
            return $quote->refresh();
        });

        $this->auditLogService->record(
            $request->user(), 'quote.created', 'quote', $quote->id,
            "Teklif oluşturuldu: {$quote->code}", ['total_minor' => $quote->total_minor]
        );

        return (new QuoteResource($quote->load('items')))->response()->setStatusCode(201);
    }

    public function show(Quote $quote): QuoteResource
    {
        Gate::authorize('view', $quote);

        return new QuoteResource($quote->load('items'));
    }

    public function update(UpdateQuoteRequest $request, Quote $quote): JsonResponse
    {
        Gate::authorize('update', $quote);

        $data = $request->validated();
        $baseVersion = $data['base_version'];
        unset($data['base_version']);

        $conflict = $this->detectVersionConflict(
            $this->syncConflictService, $request->user(), $quote, 'quote', $data, $baseVersion
        );

        if ($conflict) {
            return (new SyncConflictResource($conflict))->response()->setStatusCode(409);
        }

        $quote->update($data);

        return (new QuoteResource($quote->load('items')))->response();
    }
}
