<?php

declare(strict_types=1);

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CustomerController;
use App\Http\Controllers\Api\V1\JobController;
use App\Http\Controllers\Api\V1\JobNoteController;
use App\Http\Controllers\Api\V1\JobPhotoController;
use App\Http\Controllers\Api\V1\JobSignatureController;
use App\Http\Controllers\Api\V1\ServiceRequestController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->name('api.v1.')->group(function (): void {
    Route::post('/auth/register', [AuthController::class, 'register'])->name('auth.register');
    Route::post('/auth/login', [AuthController::class, 'login'])->name('auth.login');

    // İmzalı, süreli dosya erişimi — kasıtlı olarak auth:sanctum dışında;
    // güvenliği `signed` middleware'i (URL::temporarySignedRoute) sağlar.
    // Bkz. docs/09 § Dosya Güvenliği, madde 2.
    Route::middleware('signed')->prefix('files')->name('files.')->group(function (): void {
        Route::get('/photos/{photo}', [JobPhotoController::class, 'signedDownload'])->name('photos.show');
        // Not: parametre kasıtlı olarak "signature" değil — Laravel imzalı
        // URL'lerde "signature" query string anahtarını kendisi için ayırır,
        // aynı isimde bir route parametresiyle çakışırsa exception fırlatır.
        Route::get('/signatures/{signatureId}', [JobSignatureController::class, 'signedDownload'])->name('signatures.show');
    });

    Route::middleware('auth:sanctum')->group(function (): void {
        Route::get('/auth/me', [AuthController::class, 'me'])->name('auth.me');
        Route::post('/auth/logout', [AuthController::class, 'logout'])->name('auth.logout');

        Route::apiResource('customers', CustomerController::class);

        Route::apiResource('service-requests', ServiceRequestController::class)
            ->only(['index', 'store', 'show', 'update']);
        Route::post('/service-requests/{serviceRequest}/convert', [ServiceRequestController::class, 'convert'])
            ->name('service-requests.convert');

        Route::apiResource('jobs', JobController::class);

        Route::prefix('jobs/{job}')->name('jobs.')->group(function (): void {
            Route::apiResource('notes', JobNoteController::class)->only(['index', 'store', 'destroy']);

            Route::apiResource('photos', JobPhotoController::class)->only(['index', 'store', 'destroy']);
            Route::get('photos/{photo}/download', [JobPhotoController::class, 'download'])->name('photos.download');

            Route::apiResource('signatures', JobSignatureController::class)->only(['index', 'store']);
            Route::get('signatures/{signature}/download', [JobSignatureController::class, 'download'])->name('signatures.download');
        });
    });
});
