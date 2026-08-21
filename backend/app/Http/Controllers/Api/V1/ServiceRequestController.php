<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\AcceptsClientGeneratedId;
use App\Http\Concerns\DetectsSyncConflicts;
use App\Http\Controllers\Controller;
use App\Http\Requests\ServiceRequest\StoreServiceRequestRequest;
use App\Http\Requests\ServiceRequest\UpdateServiceRequestRequest;
use App\Http\Resources\JobResource;
use App\Http\Resources\ServiceRequestResource;
use App\Http\Resources\SyncConflictResource;
use App\Models\ServiceRequest;
use App\Services\ServiceRequestService;
use App\Services\SyncConflictService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class ServiceRequestController extends Controller
{
    use AcceptsClientGeneratedId;
    use DetectsSyncConflicts;

    public function __construct(
        private readonly ServiceRequestService $serviceRequestService,
        private readonly SyncConflictService $syncConflictService,
    ) {
    }

    public function index(Request $request): AnonymousResourceCollection
    {
        Gate::authorize('viewAny', ServiceRequest::class);

        $serviceRequests = ServiceRequest::query()
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->input('status')))
            ->latest('created_at')
            ->paginate((int) $request->input('per_page', 20));

        return ServiceRequestResource::collection($serviceRequests);
    }

    public function store(StoreServiceRequestRequest $request): JsonResponse
    {
        Gate::authorize('create', ServiceRequest::class);

        if ($existing = $this->findExistingByClientId(ServiceRequest::class, $request->input('id'))) {
            return (new ServiceRequestResource($existing))->response()->setStatusCode(200);
        }

        $serviceRequest = ServiceRequest::create($request->validated());
        $serviceRequest->refresh();

        return (new ServiceRequestResource($serviceRequest))->response()->setStatusCode(201);
    }

    public function show(ServiceRequest $serviceRequest): ServiceRequestResource
    {
        Gate::authorize('view', $serviceRequest);

        return new ServiceRequestResource($serviceRequest);
    }

    public function update(UpdateServiceRequestRequest $request, ServiceRequest $serviceRequest): JsonResponse
    {
        Gate::authorize('update', $serviceRequest);

        $data = $request->validated();
        $baseVersion = $data['base_version'];
        unset($data['base_version']);

        $conflict = $this->detectVersionConflict(
            $this->syncConflictService, $request->user(), $serviceRequest, 'service_request', $data, $baseVersion
        );

        if ($conflict) {
            return (new SyncConflictResource($conflict))->response()->setStatusCode(409);
        }

        $serviceRequest->update($data);

        return (new ServiceRequestResource($serviceRequest))->response();
    }

    public function convert(ServiceRequest $serviceRequest): JsonResponse
    {
        Gate::authorize('update', $serviceRequest);

        $job = $this->serviceRequestService->convertToJob($serviceRequest);

        return (new JobResource($job))->response()->setStatusCode(201);
    }
}
