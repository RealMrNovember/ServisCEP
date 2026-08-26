<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\AcceptsClientGeneratedId;
use App\Http\Controllers\Controller;
use App\Http\Requests\Job\StoreJobSignatureRequest;
use App\Http\Resources\JobSignatureResource;
use App\Models\Job;
use App\Models\JobSignature;
use App\Services\JobMediaService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

class JobSignatureController extends Controller
{
    use AcceptsClientGeneratedId;

    public function __construct(private readonly JobMediaService $jobMediaService) {}

    public function index(Job $job): AnonymousResourceCollection
    {
        Gate::authorize('view', $job);

        return JobSignatureResource::collection($job->signatures()->latest('created_at')->get());
    }

    public function store(StoreJobSignatureRequest $request, Job $job): JsonResponse
    {
        Gate::authorize('update', $job);

        if ($existing = $this->findExistingByClientId(JobSignature::class, $request->input('id'))) {
            return (new JobSignatureResource($existing))->response()->setStatusCode(200);
        }

        $signature = $this->jobMediaService->storeSignature(
            $job,
            $request->file('file'),
            $request->string('signer_name')->toString(),
            $request->input('id')
        );

        return (new JobSignatureResource($signature))->response()->setStatusCode(201);
    }

    public function download(Job $job, JobSignature $signature): StreamedResponse
    {
        Gate::authorize('view', $job);
        abort_unless($signature->job_id === $job->id, 404);

        return Storage::disk('local')->response($signature->file_path);
    }

    /**
     * İmzalı, süreli erişim linki — bkz. JobPhotoController::signedDownload().
     * Route parametresi kasıtlı olarak $signatureId (bkz. routes/api.php).
     */
    public function signedDownload(JobSignature $signatureId): StreamedResponse
    {
        return Storage::disk('local')->response($signatureId->file_path);
    }
}
