<?php

declare(strict_types=1);

use App\Http\Controllers\Api\V1\AuditLogController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CustomerLedgerController;
use App\Http\Controllers\Api\V1\CompanyController;
use App\Http\Controllers\Api\V1\CustomerController;
use App\Http\Controllers\Api\V1\CustomerTaxCertificateController;
use App\Http\Controllers\Api\V1\DeviceTokenController;
use App\Http\Controllers\Api\V1\ExpenseEntryController;
use App\Http\Controllers\Api\V1\IncomeEntryController;
use App\Http\Controllers\Api\V1\JobController;
use App\Http\Controllers\Api\V1\LedgerEntryController;
use App\Http\Controllers\Api\V1\LogoController;
use App\Http\Controllers\Api\V1\JobNoteController;
use App\Http\Controllers\Api\V1\JobPhotoController;
use App\Http\Controllers\Api\V1\JobSignatureController;
use App\Http\Controllers\Api\V1\PaymentController;
use App\Http\Controllers\Api\V1\PersonnelController;
use App\Http\Controllers\Api\V1\PlanController;
use App\Http\Controllers\Api\V1\ProfileController;
use App\Http\Controllers\Api\V1\ProformaController;
use App\Http\Controllers\Api\V1\QuoteController;
use App\Http\Controllers\Api\V1\ServiceRequestController;
use App\Http\Controllers\Api\V1\SubscriptionController;
use App\Http\Controllers\Api\V1\SubscriptionPaymentRequestController;
use App\Http\Controllers\Api\V1\SyncConflictController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->name('api.v1.')->group(function (): void {
    // Bkz. docs/09 § 2 Güvenlik Kontrol Listesi — "API rate limiting".
    // Brute-force/spam koruması için IP başına dakikada 10 istek.
    Route::middleware('throttle:10,1')->group(function (): void {
        Route::post('/auth/register', [AuthController::class, 'register'])->name('auth.register');
        Route::post('/auth/login', [AuthController::class, 'login'])->name('auth.login');
        Route::post('/auth/google/login', [AuthController::class, 'googleLogin'])->name('auth.google.login');
        Route::post('/auth/google/register', [AuthController::class, 'googleRegister'])->name('auth.google.register');
    });

    // İmzalı, süreli dosya erişimi — kasıtlı olarak auth:sanctum dışında;
    // güvenliği `signed` middleware'i (URL::temporarySignedRoute) sağlar.
    // Bkz. docs/09 § Dosya Güvenliği, madde 2.
    Route::middleware('signed')->prefix('files')->name('files.')->group(function (): void {
        Route::get('/photos/{photo}', [JobPhotoController::class, 'signedDownload'])->name('photos.show');
        // Not: parametre kasıtlı olarak "signature" değil — Laravel imzalı
        // URL'lerde "signature" query string anahtarını kendisi için ayırır,
        // aynı isimde bir route parametresiyle çakışırsa exception fırlatır.
        Route::get('/signatures/{signatureId}', [JobSignatureController::class, 'signedDownload'])->name('signatures.show');
        Route::get('/tax-certificates/{customer}', [CustomerTaxCertificateController::class, 'signedDownload'])
            ->name('tax-certificates.show');
    });

    Route::middleware(['auth:sanctum', 'throttle:120,1'])->group(function (): void {
        // Bu dış grup, abonelik süresi DOLMUŞ olsa da erişilebilir kalır:
        // kullanıcı kim olduğunu görebilmeli, çıkış yapabilmeli ve
        // aboneliğini yenileyebilmelidir (bkz. EnsureSubscriptionIsActive).
        Route::get('/auth/me', [AuthController::class, 'me'])->name('auth.me');
        Route::post('/auth/logout', [AuthController::class, 'logout'])->name('auth.logout');

        // Kendi profili — abonelik süresi dolsa da erişilebilir olmalı
        // (kullanıcı en azından parolasını değiştirebilmeli).
        Route::put('/auth/profile', [ProfileController::class, 'update'])->name('auth.profile.update');
        Route::put('/auth/password', [ProfileController::class, 'updatePassword'])->name('auth.password.update');

        // Abonelik — web'deki Filament App "Abonelik" sayfasının mobil
        // karşılığı: durum + paketler + havale bildirimi (admin onaylı akış).
        // Push bildirimi cihaz kaydı — abonelik süresi dolsa da çalışır
        // (kullanıcı yenileme bildirimini alabilmeli).
        Route::post('/devices', [DeviceTokenController::class, 'store'])->name('devices.store');
        Route::delete('/devices', [DeviceTokenController::class, 'destroy'])->name('devices.destroy');

        Route::get('/plans', [PlanController::class, 'index'])->name('plans.index');
        Route::get('/subscription', [SubscriptionController::class, 'show'])->name('subscription.show');
        Route::get('/subscription/payment-requests', [SubscriptionPaymentRequestController::class, 'index'])
            ->name('subscription.payment-requests.index');
        Route::post('/subscription/payment-requests', [SubscriptionPaymentRequestController::class, 'store'])
            ->name('subscription.payment-requests.store');

        Route::middleware('subscription.active')->group(function (): void {

        Route::get('/audit-logs', [AuditLogController::class, 'index'])->name('audit-logs.index');

        // Şirket ayarları — bkz. CompanyController (şirket oturumdan gelir).
        Route::get('/company', [CompanyController::class, 'show'])->name('company.show');
        Route::put('/company', [CompanyController::class, 'update'])->name('company.update');

        // Belge antedinde kullanılan logo (bkz. LogoController).
        Route::post('/company/logo', [LogoController::class, 'storeCompanyLogo'])->name('company.logo.store');
        Route::get('/company/logo', [LogoController::class, 'showCompanyLogo'])->name('company.logo.show');
        Route::delete('/company/logo', [LogoController::class, 'destroyCompanyLogo'])->name('company.logo.destroy');

        // Personel yönetimi (yalnızca işletme sahibi) — bkz. docs/09 § 1.
        Route::get('/personnel', [PersonnelController::class, 'index'])->name('personnel.index');
        Route::post('/personnel', [PersonnelController::class, 'store'])->name('personnel.store');
        Route::put('/personnel/{personnel}', [PersonnelController::class, 'update'])->name('personnel.update');
        Route::delete('/personnel/{personnel}', [PersonnelController::class, 'destroy'])->name('personnel.destroy');

        // Cari hesap hareketleri — mobil senkronun pull ucu (şirket geneli).
        Route::get('/ledger-entries', [LedgerEntryController::class, 'index'])->name('ledger-entries.index');

        Route::apiResource('sync-conflicts', SyncConflictController::class)->only(['index']);
        Route::post('sync-conflicts/{syncConflict}/resolve', [SyncConflictController::class, 'resolve'])
            ->name('sync-conflicts.resolve');

        // Not: /customers/trash, {customer} joker parametresiyle çakışmaması
        // için apiResource'tan ÖNCE tanımlanmalı (Laravel ilk eşleşeni kullanır).
        Route::get('customers/trash', [CustomerController::class, 'trashed'])->name('customers.trashed');
        Route::post('customers/{customer}/restore', [CustomerController::class, 'restore'])->name('customers.restore');

        Route::apiResource('customers', CustomerController::class);

        Route::prefix('customers/{customer}')->name('customers.')->group(function (): void {
            Route::get('ledger', [CustomerLedgerController::class, 'index'])->name('ledger.index');
            Route::post('ledger/adjustments', [CustomerLedgerController::class, 'storeAdjustment'])->name('ledger.adjustments.store');

            Route::get('payments', [PaymentController::class, 'index'])->name('payments.index');
            Route::post('payments', [PaymentController::class, 'store'])->name('payments.store');

            // Vergi levhası — web panelindeki FileUpload alanının mobil
            // karşılığı (tek dosya; yeni yükleme öncekinin yerine geçer).
            Route::post('tax-certificate', [CustomerTaxCertificateController::class, 'store'])
                ->name('tax-certificate.store');
            Route::get('tax-certificate', [CustomerTaxCertificateController::class, 'download'])
                ->name('tax-certificate.download');
            Route::delete('tax-certificate', [CustomerTaxCertificateController::class, 'destroy'])
                ->name('tax-certificate.destroy');

            // Müşteri logosu — belgede karşı tarafın markası için (opsiyonel).
            Route::post('logo', [LogoController::class, 'storeCustomerLogo'])->name('logo.store');
            Route::get('logo', [LogoController::class, 'showCustomerLogo'])->name('logo.show');
            Route::delete('logo', [LogoController::class, 'destroyCustomerLogo'])->name('logo.destroy');
        });

        Route::apiResource('quotes', QuoteController::class)->only(['index', 'store', 'show', 'update']);
        Route::apiResource('proformas', ProformaController::class)->only(['index', 'store', 'show', 'update']);

        Route::apiResource('income-entries', IncomeEntryController::class)->only(['index', 'store']);
        Route::apiResource('expense-entries', ExpenseEntryController::class)->only(['index', 'store']);

        Route::apiResource('service-requests', ServiceRequestController::class)
            ->only(['index', 'store', 'show', 'update']);
        Route::post('/service-requests/{serviceRequest}/convert', [ServiceRequestController::class, 'convert'])
            ->name('service-requests.convert');

        // Not: destroy yok — bkz. docs/09 § Veri Silme Prensibi (kritik
        // belgelerde silme yerine İPTAL durumu, bkz. JobPolicy).
        Route::apiResource('jobs', JobController::class)->only(['index', 'store', 'show', 'update']);

        Route::prefix('jobs/{job}')->name('jobs.')->group(function (): void {
            Route::apiResource('notes', JobNoteController::class)->only(['index', 'store', 'destroy']);

            Route::apiResource('photos', JobPhotoController::class)->only(['index', 'store', 'destroy']);
            Route::get('photos/{photo}/download', [JobPhotoController::class, 'download'])->name('photos.download');

            Route::apiResource('signatures', JobSignatureController::class)->only(['index', 'store']);
            Route::get('signatures/{signature}/download', [JobSignatureController::class, 'download'])->name('signatures.download');
        });

        }); // subscription.active
    });
});
