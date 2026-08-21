<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\CalculatesDocumentTotal;
use App\Http\Controllers\Controller;
use App\Http\Requests\Quote\StoreQuoteRequest;
use App\Http\Requests\Quote\UpdateQuoteRequest;
use App\Http\Resources\QuoteResource;
use App\Models\Quote;
use App\Services\AuditLogService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

class QuoteController extends Controller
{
    use CalculatesDocumentTotal;

    public function __construct(private readonly AuditLogService $auditLogService)
    {
    }

    public function index(Request $request): AnonymousResourceCollection
    {
        Gate::authorize('viewAny', Quote::class);

        $quotes = Quote::query()
            ->when($request->filled('customer_id'), fn ($query) => $query->where('customer_id', $request->input('customer_id')))
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->input('status')))
            ->latest('created_at')
            ->paginate((int) $request->input('per_page', 20));

        return QuoteResource::collection($quotes);
    }

    public function store(StoreQuoteRequest $request): JsonResponse
    {
        Gate::authorize('create', Quote::class);

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

    public function update(UpdateQuoteRequest $request, Quote $quote): QuoteResource
    {
        Gate::authorize('update', $quote);

        $quote->update($request->validated());

        return new QuoteResource($quote->load('items'));
    }
}
