<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\CustomerLedgerEntry;
use App\Models\Job;
use App\Models\Payment;
use App\Models\User;

/**
 * Cari hesap hareketleri — bkz. docs/15-cari-hesap.md. Bakiye her zaman
 * SUM(DEBIT)-SUM(CREDIT) olarak türetilir, ayrıca cache'lenmez. Kayıtlar
 * immutable'dır; düzeltme yeni bir "Manuel Düzeltme" kaydıyla yapılır.
 *
 * ⚠️ "Mükerrer kayıt uyarısı" (bkz. docs/15): fatura kesilmesi ayrıca
 * borç kaydı oluşturmaz — borç kaynağı tekildir: iş (job) tamamlanması.
 */
class CustomerLedgerService
{
    public function recordJobCompletion(Job $job): CustomerLedgerEntry
    {
        return CustomerLedgerEntry::create([
            'company_id' => $job->company_id,
            'customer_id' => $job->customer_id,
            'type' => 'DEBIT',
            'amount_minor' => $job->actual_price_minor,
            'reference_type' => 'job',
            'reference_id' => $job->id,
            'description' => "İş tamamlandı: {$job->title}",
        ])->refresh();
    }

    public function recordPayment(Payment $payment): CustomerLedgerEntry
    {
        return CustomerLedgerEntry::create([
            'company_id' => $payment->company_id,
            'customer_id' => $payment->customer_id,
            'type' => 'CREDIT',
            'amount_minor' => $payment->amount_minor,
            'reference_type' => 'payment',
            'reference_id' => $payment->id,
            'description' => "Tahsilat ({$payment->method})",
        ])->refresh();
    }

    public function recordManualAdjustment(User $user, string $customerId, string $type, int $amountMinor, string $description): CustomerLedgerEntry
    {
        return CustomerLedgerEntry::create([
            'company_id' => $user->company_id,
            'customer_id' => $customerId,
            'type' => $type,
            'amount_minor' => $amountMinor,
            'reference_type' => 'manual_adjustment',
            'reference_id' => null,
            'description' => $description,
        ])->refresh();
    }
}
