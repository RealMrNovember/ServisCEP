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
     */
    public function convertToJob(ServiceRequest $serviceRequest): Job
    {
        if ($serviceRequest->status === 'ISE_DONUSTU') {
            throw ValidationException::withMessages([
                'status' => ['Bu talep zaten bir işe dönüştürülmüş.'],
            ]);
        }

        return DB::transaction(function () use ($serviceRequest) {
            $job = Job::create([
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
