<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\SyncConflict\ResolveSyncConflictRequest;
use App\Http\Resources\SyncConflictResource;
use App\Models\Customer;
use App\Models\Job;
use App\Models\Proforma;
use App\Models\Quote;
use App\Models\ServiceRequest;
use App\Models\SyncConflict;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class SyncConflictController extends Controller
{
    /**
     * subject_type -> Model sınıfı eşlemesi — yalnızca çakışma
     * çözümünde "mobil hali tutulsun" seçildiğinde kullanılır.
     *
     * @var array<string, class-string>
     */
    private const SUBJECT_MODELS = [
        'customer' => Customer::class,
        'job' => Job::class,
        'service_request' => ServiceRequest::class,
        'quote' => Quote::class,
        'proforma' => Proforma::class,
    ];

    public function index(Request $request): AnonymousResourceCollection
    {
        Gate::authorize('viewAny', SyncConflict::class);

        $conflicts = SyncConflict::query()
            ->when($request->filled('resolution'), fn ($query) => $query->where('resolution', $request->input('resolution')))
            ->latest('created_at')
            ->paginate((int) $request->input('per_page', 30));

        return SyncConflictResource::collection($conflicts);
    }

    /**
     * OWNER, sunucudaki hali mi yoksa mobilin göndermeye çalıştığı hali
     * mi kalacağına karar verir. "Mobil hali tutulsun" seçilirse,
     * içerideki değerler ŞİMDİ (çakışma olmadan, çünkü karar bilinçli
     * verildi) uygulanır. Bkz. ROADMAP.md § B10.
     */
    public function resolve(ResolveSyncConflictRequest $request, SyncConflict $syncConflict): SyncConflictResource
    {
        Gate::authorize('resolve', $syncConflict);

        if ($syncConflict->resolution !== 'BEKLIYOR') {
            abort(422, 'Bu çakışma zaten çözüldü.');
        }

        $resolution = $request->string('resolution')->toString();

        if ($resolution === 'MOBIL_TUTULDU') {
            $modelClass = self::SUBJECT_MODELS[$syncConflict->subject_type] ?? null;
            $model = $modelClass ? $modelClass::find($syncConflict->subject_id) : null;

            if ($model) {
                $payload = collect($syncConflict->incoming_payload)
                    ->except(['id', 'base_version'])
                    ->all();
                $model->update($payload);
            }
        }

        $syncConflict->update([
            'resolution' => $resolution,
            'resolved_by' => $request->user()->id,
            'resolved_at' => now(),
        ]);

        return new SyncConflictResource($syncConflict);
    }
}
