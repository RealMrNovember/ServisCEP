<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\CalculatesDocumentTotal;
use App\Http\Controllers\Controller;
use App\Http\Requests\Proforma\StoreProformaRequest;
use App\Http\Requests\Proforma\UpdateProformaRequest;
use App\Http\Resources\ProformaResource;
use App\Models\Proforma;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

class ProformaController extends Controller
{
    use CalculatesDocumentTotal;

    public function index(Request $request): AnonymousResourceCollection
    {
        Gate::authorize('viewAny', Proforma::class);

        $proformas = Proforma::query()
            ->when($request->filled('customer_id'), fn ($query) => $query->where('customer_id', $request->input('customer_id')))
            ->latest('created_at')
            ->paginate((int) $request->input('per_page', 20));

        return ProformaResource::collection($proformas);
    }

    public function store(StoreProformaRequest $request): JsonResponse
    {
        Gate::authorize('create', Proforma::class);

        $data = $request->validated();
        $items = $data['items'];
        unset($data['items']);
        $data['total_minor'] = $this->calculateItemsTotal($items);

        $proforma = DB::transaction(function () use ($data, $items) {
            $proforma = Proforma::create($data);

            foreach ($items as $item) {
                $proforma->items()->create($item);
            }

            // created_at, DB'nin useCurrent() varsayılanıyla doluyor —
            // bellekteki modelde bu değer yoktur, refresh() gerekir.
            return $proforma->refresh();
        });

        return (new ProformaResource($proforma->load('items')))->response()->setStatusCode(201);
    }

    public function show(Proforma $proforma): ProformaResource
    {
        Gate::authorize('view', $proforma);

        return new ProformaResource($proforma->load('items'));
    }

    public function update(UpdateProformaRequest $request, Proforma $proforma): ProformaResource
    {
        Gate::authorize('update', $proforma);

        $proforma->update($request->validated());

        return new ProformaResource($proforma->load('items'));
    }
}
