<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\PaymentRequest;
use App\Models\SubscriptionPayment;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Şirketin abonelik ödeme geçmişi — kart ve havale BİR ARADA.
 *
 * Kullanıcı için ikisi aynı şeydir: "ne zaman, ne kadar ödedim, ne oldu".
 * İki ayrı liste göstermek, aynı sorunun cevabını iki yere bölmek olurdu.
 * Kaynak farkı `kind` alanıyla belirtilir.
 *
 * Yalnızca KENDİ şirketinin kayıtları döner.
 */
class SubscriptionHistoryController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $companyId = $request->user()->company_id;

        $kartlar = SubscriptionPayment::with('plan')
            ->where('company_id', $companyId)
            ->latest('created_at')
            ->limit(100)
            ->get()
            ->map(fn (SubscriptionPayment $p) => [
                'id' => $p->id,
                'kind' => 'card',
                'created_at' => $p->created_at?->toISOString(),
                'paid_at' => $p->paid_at?->toISOString(),
                'amount_minor' => $p->amount_minor,
                'currency' => $p->currency,
                'plan_name' => $p->plan?->name,
                'duration' => $p->duration,
                'status' => $p->status,
                'reference' => $p->provider_ref,
                'note' => $p->status === SubscriptionPayment::STATUS_FAILED
                    ? ($p->provider_payload['failed_reason_msg'] ?? null)
                    : null,
            ]);

        $havaleler = PaymentRequest::with('plan')
            ->where('company_id', $companyId)
            ->latest('created_at')
            ->limit(100)
            ->get()
            ->map(fn (PaymentRequest $r) => [
                'id' => $r->id,
                'kind' => 'transfer',
                'created_at' => $r->created_at?->toISOString(),
                // Havalede "ödeme anı" onay anıdır: para o an bize
                // geçmiş sayılır, beyan anı değil.
                'paid_at' => $r->status === 'APPROVED'
                    ? $r->reviewed_at?->toISOString()
                    : null,
                'amount_minor' => $r->claimed_amount_minor,
                'currency' => 'TRY',
                'plan_name' => $r->plan?->name,
                'duration' => $r->approved_duration,
                // Durum adları kart akışıyla AYNI kelimelere çevrilir;
                // kullanıcı iki farklı sözlük öğrenmek zorunda değil.
                'status' => match ($r->status) {
                    'APPROVED' => SubscriptionPayment::STATUS_PAID,
                    'REJECTED' => SubscriptionPayment::STATUS_FAILED,
                    default => SubscriptionPayment::STATUS_PENDING,
                },
                'reference' => null,
                // Yöneticinin notu HER İKİ durumda da gösterilir.
                //
                // Redde: "reddedildi" deyip susmak kullanıcıyı ne
                // yapacağını bilmeden bırakır. Onayda: ödemenin başka bir
                // pakete sayıldığı gibi açıklamalar burada kalıcı olarak
                // durmalı — bildirim kaybolur, kayıt kalır.
                'note' => in_array($r->status, ['REJECTED', 'APPROVED'], true)
                    ? $r->admin_note
                    : null,
            ]);

        $hepsi = $kartlar->concat($havaleler)
            ->sortByDesc('created_at')
            ->values();

        return response()->json(['data' => $hepsi]);
    }
}
