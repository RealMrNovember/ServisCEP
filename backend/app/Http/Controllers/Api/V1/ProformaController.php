<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\AcceptsClientGeneratedId;
use App\Http\Concerns\DetectsSyncConflicts;
use App\Http\Controllers\Controller;
use App\Http\Requests\Proforma\StoreProformaRequest;
use App\Http\Requests\Proforma\UpdateProformaRequest;
use App\Http\Resources\ProformaResource;
use App\Http\Resources\SyncConflictResource;
use App\Models\Proforma;
use App\Services\AuditLogService;
use App\Services\SyncConflictService;
use App\Support\DocumentTotal;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

class ProformaController extends Controller
{
    use AcceptsClientGeneratedId;
    use DetectsSyncConflicts;

    public function __construct(
        private readonly AuditLogService $auditLogService,
        private readonly SyncConflictService $syncConflictService,
    ) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        Gate::authorize('viewAny', Proforma::class);

        $proformas = Proforma::query()
            // Mobil pull, kalemleri tek istekte alsın diye eager-load (N+1 da onlenir).
            ->with('items')
            ->when($request->filled('customer_id'), fn ($query) => $query->where('customer_id', $request->input('customer_id')))
            ->latest('created_at')
            ->paginate((int) $request->input('per_page', 20));

        return ProformaResource::collection($proformas);
    }

    public function store(StoreProformaRequest $request): JsonResponse
    {
        Gate::authorize('create', Proforma::class);

        if ($existing = $this->findExistingByClientId(Proforma::class, $request->input('id'))) {
            return (new ProformaResource($existing->load('items')))->response()->setStatusCode(200);
        }

        $data = $request->validated();
        $items = $data['items'];
        unset($data['items']);
        $data['total_minor'] = DocumentTotal::forItems($items, $data['vat_mode'] ?? 'EXCLUDED');

        $proforma = DB::transaction(function () use ($data, $items) {
            $proforma = Proforma::create($data);

            foreach ($items as $item) {
                $proforma->items()->create($item);
            }

            // created_at, DB'nin useCurrent() varsayılanıyla doluyor —
            // bellekteki modelde bu değer yoktur, refresh() gerekir.
            return $proforma->refresh();
        });

        $this->auditLogService->record(
            $request->user(), 'proforma.created', 'proforma', $proforma->id,
            "Proforma oluşturuldu: {$proforma->code}", ['total_minor' => $proforma->total_minor]
        );

        return (new ProformaResource($proforma->load('items')))->response()->setStatusCode(201);
    }

    public function show(Proforma $proforma): ProformaResource
    {
        Gate::authorize('view', $proforma);

        return new ProformaResource($proforma->load('items'));
    }

    public function update(UpdateProformaRequest $request, Proforma $proforma): JsonResponse
    {
        Gate::authorize('update', $proforma);

        $data = $request->validated();
        $baseVersion = $data['base_version'];
        $changedFields = $data['changed_fields'] ?? [];
        unset($data['base_version'], $data['changed_fields']);

        $outcome = $this->resolveVersionConflict(
            $this->syncConflictService, $request->user(), $proforma, 'proforma',
            $data, $baseVersion, $changedFields
        );

        if ($outcome->isConflict()) {
            return (new SyncConflictResource($outcome->conflict))->response()->setStatusCode(409);
        }

        // Birleştirilmiş bir sonuçta $data yalnızca istemcinin
        // değiştirdiği alanları içerir; sunucudaki diğer değişiklikler
        // olduğu gibi kalır.
        $data = $outcome->data;

        $proforma->update($data);

        return (new ProformaResource($proforma->load('items')))->response();
    }
}
