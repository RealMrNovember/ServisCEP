<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\AcceptsClientGeneratedId;
use App\Http\Controllers\Controller;
use App\Http\Requests\Finance\StoreIncomeEntryRequest;
use App\Http\Resources\IncomeEntryResource;
use App\Models\IncomeEntry;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class IncomeEntryController extends Controller
{
    use AcceptsClientGeneratedId;

    public function index(Request $request): AnonymousResourceCollection
    {
        Gate::authorize('viewAny', IncomeEntry::class);

        $entries = IncomeEntry::query()
            ->latest('date')
            ->paginate((int) $request->input('per_page', 20));

        return IncomeEntryResource::collection($entries);
    }

    public function store(StoreIncomeEntryRequest $request): JsonResponse
    {
        Gate::authorize('create', IncomeEntry::class);

        if ($existing = $this->findExistingByClientId(IncomeEntry::class, $request->input('id'))) {
            return (new IncomeEntryResource($existing))->response()->setStatusCode(200);
        }

        $entry = IncomeEntry::create($request->validated())->refresh();

        return (new IncomeEntryResource($entry))->response()->setStatusCode(201);
    }
}
