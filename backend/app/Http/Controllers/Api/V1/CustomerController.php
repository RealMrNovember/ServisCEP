<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Customer\StoreCustomerRequest;
use App\Http\Requests\Customer\UpdateCustomerRequest;
use App\Http\Resources\CustomerResource;
use App\Models\Customer;
use App\Services\AuditLogService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Gate;

class CustomerController extends Controller
{
    public function __construct(private readonly AuditLogService $auditLogService)
    {
    }

    public function index(Request $request): AnonymousResourceCollection
    {
        Gate::authorize('viewAny', Customer::class);

        $customers = Customer::query()
            ->when($request->filled('q'), function ($query) use ($request) {
                $term = '%'.$request->input('q').'%';
                $query->where(function ($query) use ($term) {
                    $query->where('contact_name', 'like', $term)
                        ->orWhere('company_name', 'like', $term)
                        ->orWhere('phone', 'like', $term);
                });
            })
            ->when($request->filled('type'), fn ($query) => $query->where('type', $request->input('type')))
            ->latest('created_at')
            ->paginate((int) $request->input('per_page', 20));

        return CustomerResource::collection($customers);
    }

    public function store(StoreCustomerRequest $request): JsonResponse
    {
        Gate::authorize('create', Customer::class);

        $customer = Customer::create($request->validated());

        // created_at, DB'nin useCurrent() varsayılanıyla dolduruluyor
        // (Customer::$timestamps = false) — bellekteki modelde bu değer
        // yoktur, refresh() ile DB'den geri okunmalı.
        $customer->refresh();

        $this->auditLogService->record(
            $request->user(), 'customer.created', 'customer', $customer->id,
            "Müşteri oluşturuldu: {$customer->display_name}"
        );

        return (new CustomerResource($customer))->response()->setStatusCode(201);
    }

    public function show(Customer $customer): CustomerResource
    {
        Gate::authorize('view', $customer);

        return new CustomerResource($customer);
    }

    public function update(UpdateCustomerRequest $request, Customer $customer): CustomerResource
    {
        Gate::authorize('update', $customer);

        $customer->update($request->validated());

        $this->auditLogService->record(
            $request->user(), 'customer.updated', 'customer', $customer->id,
            "Müşteri güncellendi: {$customer->display_name}"
        );

        return new CustomerResource($customer);
    }

    public function destroy(Request $request, Customer $customer): Response
    {
        Gate::authorize('delete', $customer);

        $customer->delete();

        $this->auditLogService->record(
            $request->user(), 'customer.deleted', 'customer', $customer->id,
            "Müşteri silindi: {$customer->display_name}"
        );

        return response()->noContent();
    }
}
