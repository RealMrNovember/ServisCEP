<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Subscription\StorePaymentRequestRequest;
use App\Http\Resources\PaymentRequestResource;
use App\Models\PaymentRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * Abonelik ödeme talepleri (havale/EFT bildirimi) — müşteri ödemeyi kendi
 * bankasından yapar, buradan "ödedim" talebi düşer, admin panelden onaylanır
 * (PaymentRequest::approve aboneliği uzatır). "PaymentController" ile
 * karıştırma: o, müşteri cari hesap tahsilatlarını yönetir.
 */
class SubscriptionPaymentRequestController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $requests = PaymentRequest::query()
            ->with(['plan', 'approvedPlan'])
            ->where('company_id', $request->user()->company_id)
            ->orderByDesc('created_at')
            ->limit(20)
            ->get();

        return PaymentRequestResource::collection($requests);
    }

    public function store(StorePaymentRequestRequest $request): JsonResponse
    {
        $user = $request->user();
        $data = $request->validated();

        $paymentRequest = PaymentRequest::create([
            'company_id' => $user->company_id,
            'requested_by_user_id' => $user->id,
            'plan_id' => $data['plan_id'],
            'requested_duration' => $data['billing_period'],
            'claimed_amount_minor' => $data['claimed_amount_minor'] ?? null,
            'customer_note' => $data['customer_note'] ?? null,
            'status' => 'PENDING',
        ]);

        $paymentRequest->load('plan');

        return (new PaymentRequestResource($paymentRequest))->response()->setStatusCode(201);
    }
}
