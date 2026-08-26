<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\AcceptsClientGeneratedId;
use App\Http\Controllers\Controller;
use App\Http\Requests\Payment\StorePaymentRequest;
use App\Http\Resources\PaymentResource;
use App\Models\Customer;
use App\Models\Payment;
use App\Services\AuditLogService;
use App\Services\CustomerLedgerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

class PaymentController extends Controller
{
    use AcceptsClientGeneratedId;

    public function __construct(
        private readonly CustomerLedgerService $customerLedgerService,
        private readonly AuditLogService $auditLogService,
    ) {}

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

        if ($existing = $this->findExistingByClientId(Payment::class, $request->input('id'))) {
            return (new PaymentResource($existing))->response()->setStatusCode(200);
        }

        $payment = DB::transaction(function () use ($request, $customer) {
            $payment = $customer->payments()->create($request->validated());
            $payment->refresh();

            $this->customerLedgerService->recordPayment($payment);

            return $payment;
        });

        $this->auditLogService->record(
            $request->user(), 'payment.recorded', 'payment', $payment->id,
            "Tahsilat kaydedildi ({$payment->method})", ['amount_minor' => $payment->amount_minor]
        );

        return (new PaymentResource($payment))->response()->setStatusCode(201);
    }
}
