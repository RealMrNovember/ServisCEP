<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Payment\StorePaymentRequest;
use App\Http\Resources\PaymentResource;
use App\Models\Customer;
use App\Services\CustomerLedgerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

class PaymentController extends Controller
{
    public function __construct(private readonly CustomerLedgerService $customerLedgerService)
    {
    }

    public function index(Customer $customer): AnonymousResourceCollection
    {
        Gate::authorize('view', $customer);

        return PaymentResource::collection($customer->payments()->latest('date')->paginate(20));
    }

    /**
     * Tahsilat kaydı — aynı anda otomatik ALACAK cari hesap hareketi
     * oluşturur (bkz. docs/15 § Otomatik Kayıt Oluşturma), tek transaction.
     */
    public function store(StorePaymentRequest $request, Customer $customer): JsonResponse
    {
        Gate::authorize('update', $customer);

        $payment = DB::transaction(function () use ($request, $customer) {
            $payment = $customer->payments()->create($request->validated());
            $payment->refresh();

            $this->customerLedgerService->recordPayment($payment);

            return $payment;
        });

        return (new PaymentResource($payment))->response()->setStatusCode(201);
    }
}
