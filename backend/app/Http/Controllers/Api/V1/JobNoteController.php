<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\AcceptsClientGeneratedId;
use App\Http\Controllers\Controller;
use App\Http\Requests\Job\StoreJobNoteRequest;
use App\Http\Resources\JobNoteResource;
use App\Models\Job;
use App\Models\JobNote;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Gate;

class JobNoteController extends Controller
{
    use AcceptsClientGeneratedId;

    public function index(Job $job): AnonymousResourceCollection
    {
        Gate::authorize('view', $job);

        return JobNoteResource::collection($job->jobNotes()->latest('created_at')->get());
    }

    public function store(StoreJobNoteRequest $request, Job $job): JsonResponse
    {
        Gate::authorize('update', $job);

        if ($existing = $this->findExistingByClientId(JobNote::class, $request->input('id'))) {
            return (new JobNoteResource($existing))->response()->setStatusCode(200);
        }

        $note = $job->jobNotes()->create($request->validated());
        $note->refresh();

        return (new JobNoteResource($note))->response()->setStatusCode(201);
    }

    public function destroy(Job $job, JobNote $note): Response
    {
        Gate::authorize('update', $job);
        abort_unless($note->job_id === $job->id, 404);

        $note->delete();

        return response()->noContent();
    }
}
