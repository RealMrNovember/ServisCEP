<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\AcceptsClientGeneratedId;
use App\Http\Controllers\Controller;
use App\Http\Requests\Job\StoreJobPhotoRequest;
use App\Http\Resources\JobPhotoResource;
use App\Models\Job;
use App\Models\JobPhoto;
use App\Services\JobMediaService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Response;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

class JobPhotoController extends Controller
{
    use AcceptsClientGeneratedId;

    public function __construct(private readonly JobMediaService $jobMediaService)
    {
    }

    public function index(Job $job): AnonymousResourceCollection
    {
        Gate::authorize('view', $job);

        return JobPhotoResource::collection($job->photos()->latest('created_at')->get());
    }

    public function store(StoreJobPhotoRequest $request, Job $job): JsonResponse
    {
        Gate::authorize('update', $job);

        if ($existing = $this->findExistingByClientId(JobPhoto::class, $request->input('id'))) {
            return (new JobPhotoResource($existing))->response()->setStatusCode(200);
        }

        $photo = $this->jobMediaService->storePhoto(
            $job, $request->file('file'), $request->string('category')->toString(), $request->input('id')
        );

        return (new JobPhotoResource($photo))->response()->setStatusCode(201);
    }

    public function download(Job $job, JobPhoto $photo): StreamedResponse
    {
        Gate::authorize('view', $job);
        abort_unless($photo->job_id === $job->id, 404);

        return Storage::disk('local')->response($photo->file_path);
    }

    /**
     * İmzalı, süreli erişim linki — `signed` middleware'i tarafından
     * korunur, kimlik doğrulama gerekmez (bkz. docs/09 § Dosya Güvenliği,
     * madde 2: "Signed URL").
     */
    public function signedDownload(JobPhoto $photo): StreamedResponse
    {
        return Storage::disk('local')->response($photo->file_path);
    }

    public function destroy(Job $job, JobPhoto $photo): Response
    {
        Gate::authorize('update', $job);
        abort_unless($photo->job_id === $job->id, 404);

        $this->jobMediaService->deletePhoto($photo);

        return response()->noContent();
    }
}
