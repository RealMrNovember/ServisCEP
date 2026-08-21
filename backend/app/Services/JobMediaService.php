<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Job;
use App\Models\JobPhoto;
use App\Models\JobSignature;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

/**
 * Fotoğraf/imza dosyaları `local` disk'te (storage/app/private) saklanır —
 * doğrudan public web klasöründen asla erişilemez (bkz. docs/09 § Dosya
 * Güvenliği). Yol biçimi: company/{company_id}/jobs/{job_id}/...
 */
class JobMediaService
{
    public function storePhoto(Job $job, UploadedFile $file, string $category): JobPhoto
    {
        $path = $file->store($this->jobDirectory($job).'/photos', 'local');

        return JobPhoto::create([
            'job_id' => $job->id,
            'category' => $category,
            'file_path' => $path,
        ])->refresh();
    }

    public function deletePhoto(JobPhoto $photo): void
    {
        Storage::disk('local')->delete($photo->file_path);
        $photo->delete();
    }

    public function storeSignature(Job $job, UploadedFile $file, string $signerName): JobSignature
    {
        $path = $file->store($this->jobDirectory($job).'/signatures', 'local');

        return JobSignature::create([
            'job_id' => $job->id,
            'signer_name' => $signerName,
            'file_path' => $path,
        ])->refresh();
    }

    private function jobDirectory(Job $job): string
    {
        return "company/{$job->company_id}/jobs/{$job->id}";
    }
}
