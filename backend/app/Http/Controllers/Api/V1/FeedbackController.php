<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Feedback\StoreFeedbackRequest;
use App\Http\Resources\FeedbackResource;
use App\Models\Feedback;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * Kullanıcının uygulama içinden gönderdiği geri bildirim.
 *
 * Tanılama ucundan (`/diagnostics`) FARKLI ve bilinçli olarak ayrı:
 * tanılama makinenin ürettiği kayıt, bu insanın yazdığı mesaj. Tanılama
 * budanıyor ve cevaplanmıyor; geri bildirim kalıcı ve cevap bekliyor.
 *
 * Kimlik doğrulaması ZORUNLU — tanılamanın aksine. Sebebi: cevap
 * yazılacak. Kimin yazdığı bilinmeyen bir mesaja cevap gönderilemez.
 */
class FeedbackController extends Controller
{
    public function store(StoreFeedbackRequest $request): JsonResponse
    {
        $user = $request->user();

        $feedback = Feedback::create([
            'company_id' => $user->company_id,
            'user_id' => $user->id,
            'type' => $request->validated('type', 'DIGER'),
            'message' => $request->validated('message'),
            // Durum AÇIKÇA yazılıyor, veritabanı varsayılanına
            // bırakılmıyor: varsayılan yalnızca satıra uygulanır, dönen
            // model nesnesi onu bilmez ve yanıtta `status` null çıkardı.
            'status' => 'YENI',
            // Künye başlıklardan okunuyor; kullanıcıya "hangi sürümü
            // kullanıyorsunuz" diye sormak zorunda kalmamak için
            // (bkz. ClientHeaders).
            'app_version' => $request->header('X-App-Version'),
            'platform' => $request->header('X-Platform'),
            'device' => $request->header('X-Device-Model'),
        ]);

        return (new FeedbackResource($feedback))->response()->setStatusCode(201);
    }

    /**
     * Kullanıcının kendi geri bildirimleri ve varsa yanıtları.
     *
     * Yanıt bildirimi kaybolabilir; kayıt kalıcı olmalı. Aynı ilke ödeme
     * taleplerinde de uygulandı.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $feedbacks = Feedback::query()
            ->where('company_id', $request->user()->company_id)
            ->orderByDesc('created_at')
            ->limit(50)
            ->get();

        return FeedbackResource::collection($feedbacks);
    }
}
