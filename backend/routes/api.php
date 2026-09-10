<?php

declare(strict_types=1);

use App\Http\Controllers\Api\V1\AppVersionController;
use App\Http\Controllers\Api\V1\AuditLogController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BarcodeLookupController;
use App\Http\Controllers\Api\V1\CompanyController;
use App\Http\Controllers\Api\V1\CustomerController;
use App\Http\Controllers\Api\V1\CustomerLedgerController;
use App\Http\Controllers\Api\V1\CustomerTaxCertificateController;
use App\Http\Controllers\Api\V1\DeviceTokenController;
use App\Http\Controllers\Api\V1\DiagnosticsController;
use App\Http\Controllers\Api\V1\ExpenseEntryController;
use App\Http\Controllers\Api\V1\FeedbackController;
use App\Http\Controllers\Api\V1\IncomeEntryController;
use App\Http\Controllers\Api\V1\JobController;
use App\Http\Controllers\Api\V1\JobNoteController;
use App\Http\Controllers\Api\V1\JobPhotoController;
use App\Http\Controllers\Api\V1\JobSignatureController;
use App\Http\Controllers\Api\V1\LedgerEntryController;
use App\Http\Controllers\Api\V1\LogoController;
use App\Http\Controllers\Api\V1\PaymentController;
use App\Http\Controllers\Api\V1\PersonnelController;
use App\Http\Controllers\Api\V1\PlanController;
use App\Http\Controllers\Api\V1\ProductBarcodeController;
use App\Http\Controllers\Api\V1\ProductController;
use App\Http\Controllers\Api\V1\ProfileController;
use App\Http\Controllers\Api\V1\ProformaController;
use App\Http\Controllers\Api\V1\QuoteController;
use App\Http\Controllers\Api\V1\ServiceRequestController;
use App\Http\Controllers\Api\V1\StockMovementController;
use App\Http\Controllers\Api\V1\SubscriptionCheckoutController;
use App\Http\Controllers\Api\V1\SubscriptionController;
use App\Http\Controllers\Api\V1\SubscriptionHistoryController;
use App\Http\Controllers\Api\V1\SubscriptionPaymentRequestController;
use App\Http\Controllers\Api\V1\SyncConflictController;
use App\Http\Middleware\LogApiRequests;
use Illuminate\Support\Facades\Route;

// Günlükleme ara katmanı rota grubunda TANIMLI (middleware grubuna
// eklenmek yerine): burada hangi isteklerin kapsandığı gözle görülür ve
// `route:list` çıktısında da doğrulanabilir.
Route::prefix('v1')->name('api.v1.')->middleware(LogApiRequests::class)->group(function (): void {
    // Bkz. docs/09 § 2 Güvenlik Kontrol Listesi — "API rate limiting".
    // Brute-force/spam koruması için IP başına dakikada 10 istek.
    Route::middleware('throttle:10,1')->group(function (): void {
        Route::post('/auth/register', [AuthController::class, 'register'])->name('auth.register');
        Route::post('/auth/login', [AuthController::class, 'login'])->name('auth.login');
        Route::post('/auth/google/login', [AuthController::class, 'googleLogin'])->name('auth.google.login');
        Route::post('/auth/google/register', [AuthController::class, 'googleRegister'])->name('auth.google.register');
    });

    // Parola sıfırlama — giriş yapılamadan çağrılır, bu yüzden kimlik
    // doğrulaması yok. Sınır grubun geri kalanından DAHA DAR: her istek
    // bir e-posta gönderiyor ve bu uç, kısıtlanmazsa üçüncü bir kişinin
    // posta kutusunu doldurmanın ücretsiz yoluna dönüşür.
    Route::middleware('throttle:5,10')->group(function (): void {
        Route::post('/auth/password/forgot', [AuthController::class, 'forgotPassword'])
            ->name('auth.password.forgot');
        Route::post('/auth/password/reset', [AuthController::class, 'resetPassword'])
            ->name('auth.password.reset');
    });

    // Yayındaki sürüm — kimlik doğrulaması yok (bkz. AppVersionController).
    // Uygulama güncel mi sorusu, giriş yapılamadığında da sorulabilmeli.
    Route::get('/app/version', [AppVersionController::class, 'show'])->name('app.version');

    // Sürüm kaydını CI yazar. Kimlik doğrulaması gövdede değil, paylaşılan
    // jetonla (bkz. AppVersionController::publish) — çağıran bir kullanıcı
    // değil, yayın hattı.
    Route::post('/app/version', [AppVersionController::class, 'publish'])
        ->middleware('throttle:10,1')
        ->name('app.version.publish');

    // Ödeme sağlayıcısının bildirimi.
    //
    // Kimlik doğrulaması YOK: istek PayTR'nin sunucusundan gelir,
    // bizim oturumumuz yoktur. Güvenlik imzayla sağlanır —
    // doğrulanmayan bir bildirim hiçbir şeyi değiştirmez.
    Route::post('/payments/paytr/callback', [SubscriptionCheckoutController::class, 'callback'])
        ->name('payments.paytr.callback');

    // Mobil tanılama — KİMLİK DOĞRULAMASI YOK.
    //
    // Bilinçli: kimlik doğrulamanın kendisi bozulduğunda hatayı bize
    // ulaştırabilecek tek yol bu uçtur. Bir cihazda tam olarak bu yaşandı
    // ve arıza günlerce görünmez kaldı. Koruma, kimlik yerine hız
    // sınırıyla sağlanır (bkz. DiagnosticsController).
    Route::middleware('throttle:20,1')->group(function (): void {
        Route::post('/diagnostics', [DiagnosticsController::class, 'store'])->name('diagnostics.store');
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
        // aboneliğini yenileyebilmelidir. (Veri uçlarındaki abonelik
        // kapısı 2026-09-10'da kaldırıldı; bkz. aşağıdaki gerekçe.)
        Route::get('/auth/me', [AuthController::class, 'me'])->name('auth.me');
        Route::post('/auth/logout', [AuthController::class, 'logout'])->name('auth.logout');

        // Kendi profili — abonelik süresi dolsa da erişilebilir olmalı
        // (kullanıcı en azından parolasını değiştirebilmeli).
        Route::put('/auth/profile', [ProfileController::class, 'update'])->name('auth.profile.update');
        Route::put('/auth/password', [ProfileController::class, 'updatePassword'])->name('auth.password.update');

        // Geri bildirim — abonelik süresi DOLMUŞ olsa da erişilebilir.
        // Aboneliği bittiği için yazamayan bir kullanıcı, tam da bu yüzden
        // bize yazmak isteyebilir; o kapıyı kapatmak anlamsız.
        //
        // Hız sınırı dar: geri bildirim insan hızında yazılır, dakikada
        // beşten fazlası kötüye kullanımdır.
        Route::middleware('throttle:5,1')
            ->post('/feedback', [FeedbackController::class, 'store'])
            ->name('feedback.store');
        Route::get('/feedback', [FeedbackController::class, 'index'])->name('feedback.index');

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
        // Ödeme geçmişi — kart ve havale bir arada.
        Route::get('/subscription/history', [SubscriptionHistoryController::class, 'index'])
            ->name('subscription.history');
        // Kartla ödeme başlatma. Tutar SUNUCUDA hesaplanır.
        Route::post('/subscription/checkout', [SubscriptionCheckoutController::class, 'checkout'])
            ->name('subscription.checkout');
        Route::post('/subscription/payment-requests', [SubscriptionPaymentRequestController::class, 'store'])
            ->name('subscription.payment-requests.store');

        // ABONELİK KAPISI BURADAN KALDIRILDI (2026-09-10).
        //
        // Süresi dolmuş bir hesabın veri uçları 402 ile kesiliyordu.
        // Sonucu şuydu: kullanıcı uygulamayı açıyor, kaydını giriyor,
        // kayıt cihazda kuyruğa giriyor ve SUNUCUYA HİÇ ULAŞMIYOR.
        // Kimlik uçları kapının dışında olduğu için kullanıcı "aktif"
        // görünüyor, veri ise iki haftadır donmuş durumdaydı — canlıda
        // tam olarak bu yaşandı (17 şirketin 9'u).
        //
        // Ödemesi gecikmiş bir müşterinin verisini rehin almak kabul
        // edilebilir bir tahsilat yöntemi değil: telefonu kaybolursa
        // yedeklenmemiş kaydı da kaybolur. Yedekleme HİÇBİR koşulda
        // durmaz.
        //
        // Ücretlendirme kapısı istemciye taşındı: uygulama, süresi
        // dolmuş hesapta YENİ KAYIT OLUŞTURMAYI engelliyor ve kullanıcıyı
        // ödeme akışına yönlendiriyor (bkz. AbonelikKapisi). Sunucu
        // birikeni kabul etmeye devam ediyor.
        //
        // Bilinçli ödünleşme: kapı yalnızca istemcide olduğu için, API'yi
        // doğrudan çağıran biri sınırı aşabilir. Bu ürün için veri kaybı
        // riski, o riskten kat kat ağır basıyor.
        Route::group([], function (): void {

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

            // ÜRÜN / STOK — 2026-09-10'da eklendi.
            //
            // Tablolar baştan beri vardı ama HİÇBİR ucu yoktu: kullanıcının
            // ürün kataloğu ve stok geçmişi yalnızca telefonunda duruyordu,
            // telefon kaybolduğunda geri getirilemiyordu. Uygulamanın kendi
            // vaadiyle de çelişiyordu (allowBackup="false" gerekçesi:
            // "tüm veri sunucuyla eşitleniyor").
            //
            // Stok hareketlerinde update/destroy YOK: defter değişmez,
            // yanlış hareket ters yönde ikinci bir hareketle düzeltilir.
            Route::apiResource('products', ProductController::class)
                ->only(['index', 'store', 'show', 'update', 'destroy']);
            Route::apiResource('stock-movements', StockMovementController::class)
                ->only(['index', 'store']);

            // Ek barkodlar: bir urune birden fazla kod baglanabilsin.
            // Seri numarali urunlerde (kamera vb.) her kutu farkli kod
            // okutuyor; tek `products.barcode` alani bunu karsilamiyordu.
            Route::apiResource('product-barcodes', ProductBarcodeController::class)
                ->only(['index', 'store', 'destroy']);

            // Taranan kodu acik urun veritabanlarinda arar (sunucu vekil
            // olarak cikiyor; onbellek paylasilsin ve saglayici degisikligi
            // uygulama surumu gerektirmesin diye).
            //
            // throttle: sorgu DISARI cikiyor. Sinirsiz birakmak, ucretsiz
            // saglayicilarin gunluk kotasini tek kullanicinin yakmasina
            // izin vermek olurdu.
            Route::get('/barcode-lookup', BarcodeLookupController::class)
                ->middleware('throttle:60,1')
                ->name('barcode-lookup');

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

        }); // veri uçları — abonelikten bağımsız
    });
});
