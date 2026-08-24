<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Job;
use App\Models\ServiceRequest;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class ServiceRequestService
{
    /**
     * Talebi işe dönüştürür — bağlam (müşteri, açıklama, öncelik, adres)
     * otomatik taşınır (bkz. docs/02 § Talep → İş Dönüşümü). Zaten
     * dönüştürülmüş bir talep tekrar dönüştürülemez.
     *
     * $clientJobId: mobilin offline dönüşümde yerel oluşturduğu işin
     * UUID'si (AcceptsClientGeneratedId ile aynı felsefe) — verilirse iş bu
     * ID ile oluşturulur ki mobildeki ilişkiler kopmasın. Aynı taleple aynı
     * job_id'nin tekrar gönderilmesi (ağ kesintisi sonrası replay) hata
     * değil, var olan işi döndürür.
     */
    public function convertToJob(ServiceRequest $serviceRequest, ?string $clientJobId = null): Job
    {
        if ($serviceRequest->status === 'ISE_DONUSTU') {
            if ($clientJobId !== null && $serviceRequest->converted_job_id === $clientJobId) {
                return Job::findOrFail($clientJobId);
            }

            throw ValidationException::withMessages([
                'status' => ['Bu talep zaten bir işe dönüştürülmüş.'],
            ]);
        }

        return DB::transaction(function () use ($serviceRequest, $clientJobId) {
            $job = Job::create([
                'id' => $clientJobId,
                'company_id' => $serviceRequest->company_id,
                'code' => 'J-'.Str::upper(Str::random(8)),
                'customer_id' => $serviceRequest->customer_id,
                'title' => Str::limit($serviceRequest->description, 80, ''),
                'description' => $serviceRequest->description,
                'address' => $serviceRequest->address,
                'priority' => $serviceRequest->priority,
                'status' => 'TALEP',
            ]);

            $serviceRequest->update([
                'status' => 'ISE_DONUSTU',
                'converted_job_id' => $job->id,
            ]);

            // created_at, DB'nin useCurrent() varsayılanıyla doluyor
            // (Job::$timestamps = false) — bellekteki modelde bu değer
            // yoktur, refresh() ile DB'den geri okunmalı (bkz.
            // CustomerController::store() ile aynı hata kalıbı).
            return $job->refresh();
        });
    }
}
