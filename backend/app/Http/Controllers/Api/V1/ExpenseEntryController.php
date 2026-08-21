<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\AcceptsClientGeneratedId;
use App\Http\Controllers\Controller;
use App\Http\Requests\Finance\StoreExpenseEntryRequest;
use App\Http\Resources\ExpenseEntryResource;
use App\Models\ExpenseEntry;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class ExpenseEntryController extends Controller
{
    use AcceptsClientGeneratedId;

    public function index(Request $request): AnonymousResourceCollection
    {
        Gate::authorize('viewAny', ExpenseEntry::class);

        $entries = ExpenseEntry::query()
            ->latest('date')
            ->paginate((int) $request->input('per_page', 20));

        return ExpenseEntryResource::collection($entries);
    }

    public function store(StoreExpenseEntryRequest $request): JsonResponse
    {
        Gate::authorize('create', ExpenseEntry::class);

        if ($existing = $this->findExistingByClientId(ExpenseEntry::class, $request->input('id'))) {
            return (new ExpenseEntryResource($existing))->response()->setStatusCode(200);
        }

        $entry = ExpenseEntry::create($request->validated())->refresh();

        return (new ExpenseEntryResource($entry))->response()->setStatusCode(201);
    }
}
