<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\AcceptsClientGeneratedId;
use App\Http\Concerns\DetectsSyncConflicts;
use App\Http\Controllers\Controller;
use App\Http\Requests\Job\StoreJobRequest;
use App\Http\Requests\Job\UpdateJobRequest;
use App\Http\Resources\JobResource;
use App\Http\Resources\SyncConflictResource;
use App\Models\CustomerLedgerEntry;
use App\Models\Job;
use App\Services\AuditLogService;
use App\Services\CustomerLedgerService;
use App\Services\SyncConflictService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

class JobController extends Controller
{
    use AcceptsClientGeneratedId;
    use DetectsSyncConflicts;

    public function __construct(
        private readonly CustomerLedgerService $customerLedgerService,
        private readonly AuditLogService $auditLogService,
        private readonly SyncConflictService $syncConflictService,
    ) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        Gate::authorize('viewAny', Job::class);

        $jobs = Job::query()
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->input('status')))
            ->when($request->filled('customer_id'), fn ($query) => $query->where('customer_id', $request->input('customer_id')))
            ->when($request->filled('q'), function ($query) use ($request) {
                $term = '%'.$request->input('q').'%';
                $query->where(function ($query) use ($term) {
                    $query->where('title', 'like', $term)->orWhere('description', 'like', $term);
                });
            })
            ->latest('created_at')
            ->paginate((int) $request->input('per_page', 20));

        return JobResource::collection($jobs);
    }

    public function store(StoreJobRequest $request): JsonResponse
    {
        Gate::authorize('create', Job::class);

        if ($existing = $this->findExistingByClientId(Job::class, $request->input('id'))) {
            return (new JobResource($existing))->response()->setStatusCode(200);
        }

        $job = Job::create($request->validated());
        $job->refresh();

        return (new JobResource($job))->response()->setStatusCode(201);
    }

    public function show(Job $job): JobResource
    {
        Gate::authorize('view', $job);

        return new JobResource($job);
    }

    public function update(UpdateJobRequest $request, Job $job): JsonResponse
    {
        Gate::authorize('update', $job);

        $data = $request->validated();
        $baseVersion = $data['base_version'];
        unset($data['base_version']);

        $conflict = $this->detectVersionConflict(
            $this->syncConflictService, $request->user(), $job, 'job', $data, $baseVersion
        );

        if ($conflict) {
            return (new SyncConflictResource($conflict))->response()->setStatusCode(409);
        }

        $previousStatus = $job->status;

        DB::transaction(function () use ($data, $job) {
            $job->update($data);

            // İş tamamlandı + gerçek fiyat girildiğinde otomatik BORÇ kaydı
            // — bkz. docs/15 § Otomatik Kayıt Oluşturma. Borç kaynağı
            // tekildir (bir iş için en fazla bir kayıt), bu yüzden zaten
            // var olan bir kayıt varsa tekrar oluşturulmaz — hem "tamamla
            // + aynı anda fiyat gir" hem "tamamla, fiyatı sonra ekle"
            // senaryolarını doğru ve tek seferlik kapsar.
            if ($job->status === 'TAMAMLANDI' && $job->actual_price_minor !== null) {
                $alreadyRecorded = CustomerLedgerEntry::query()
                    ->where('reference_type', 'job')
                    ->where('reference_id', $job->id)
                    ->exists();

                if (! $alreadyRecorded) {
                    $this->customerLedgerService->recordJobCompletion($job);
                }
            }
        });

        // Bkz. docs/09 § 5 Audit Log — audit gerektiren kritik işlem
        // örneği tam olarak bu ("Servis tamamlandı").
        if ($previousStatus !== 'TAMAMLANDI' && $job->status === 'TAMAMLANDI') {
            $this->auditLogService->record(
                $request->user(), 'job.completed', 'job', $job->id,
                "İş tamamlandı: {$job->title}", ['actual_price_minor' => $job->actual_price_minor]
            );
        } elseif ($previousStatus !== 'IPTAL' && $job->status === 'IPTAL') {
            $this->auditLogService->record(
                $request->user(), 'job.cancelled', 'job', $job->id,
                "İş iptal edildi: {$job->title}"
            );
        }

        return (new JobResource($job))->response();
    }
}
