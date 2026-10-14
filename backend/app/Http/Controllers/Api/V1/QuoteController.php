<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\AcceptsClientGeneratedId;
use App\Http\Concerns\DetectsSyncConflicts;
use App\Http\Controllers\Controller;
use App\Http\Requests\Quote\StoreQuoteRequest;
use App\Http\Requests\Quote\UpdateQuoteRequest;
use App\Http\Resources\QuoteResource;
use App\Http\Resources\SyncConflictResource;
use App\Models\Quote;
use App\Services\AuditLogService;
use App\Services\SyncConflictService;
use App\Support\DocumentTotal;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

class QuoteController extends Controller
{
    use AcceptsClientGeneratedId;
    use DetectsSyncConflicts;

    public function __construct(
        private readonly AuditLogService $auditLogService,
        private readonly SyncConflictService $syncConflictService,
    ) {}

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
        $data['total_minor'] = DocumentTotal::forItems($items, $data['vat_mode'] ?? 'EXCLUDED');

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
        $changedFields = $data['changed_fields'] ?? [];
        unset($data['base_version'], $data['changed_fields']);

        // Kalemler AYRI bir tabloda; surum birlestirmesi ise sutun bazli
        // calisiyor (bkz. DetectsSyncConflicts) ve bir iliskiyi
        // birlestiremez. Bu yuzden kalemler karardan ONCE $data'dan
        // cikarilir, karar verildikten SONRA uygulanir.
        //
        // Kalem degisikligi boylece cakisma denetiminin disinda kalmiyor:
        // kalemler degisince `total_minor` da degisiyor ve istemci onu
        // `changed_fields` icinde bildiriyor. Ofiste de kalem degistiyse
        // sunucunun izinde `total_minor` gorunur ve kesisim cakismayi
        // yakalar.
        $items = $data['items'] ?? null;
        unset($data['items']);

        if ($items !== null) {
            $data['total_minor'] = DocumentTotal::forItems($items, $data['vat_mode'] ?? $quote->vat_mode);
            // Istemci kendi duzenleme anini gonderir; gondermediyse
            // sunucu saati yedektir (bkz. edited_at gocu).
            $data['edited_at'] ??= now();
        }

        $outcome = $this->resolveVersionConflict(
            $this->syncConflictService, $request->user(), $quote, 'quote',
            $data, $baseVersion, $changedFields
        );

        if ($outcome->isConflict()) {
            return (new SyncConflictResource($outcome->conflict))->response()->setStatusCode(409);
        }

        // Birleştirilmiş bir sonuçta $data yalnızca istemcinin
        // değiştirdiği alanları içerir; sunucudaki diğer değişiklikler
        // olduğu gibi kalır.
        $data = $outcome->data;

        // Kalemler yalnizca kendi degisiklikleri karardan sag ciktiysa
        // yazilir. Birlestirme istemcinin bildirmedigi alanlari eliyor;
        // `total_minor` elendiyse kalemler de uygulanmamali, yoksa belge
        // tutari ile kalemleri birbirini tutmaz.
        $kalemleriYaz = $items !== null && array_key_exists('total_minor', $data);

        DB::transaction(function () use ($quote, $data, $items, $kalemleriYaz): void {
            $quote->update($data);

            if ($kalemleriYaz) {
                // Kalem listesi kaydin YENI hali olarak geliyor; tek tek
                // eslestirmek yerine topluca degistiriliyor. Eslestirme,
                // silinen bir kalemi tespit etmek icin ayri bir iz
                // gerektirirdi ve o iz hicbir yerde tutulmuyor.
                $quote->items()->delete();

                foreach ($items as $item) {
                    $quote->items()->create($item);
                }
            }
        });

        return (new QuoteResource($quote->load('items')))->response();
    }
}
