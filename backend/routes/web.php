<?php

use App\Http\Controllers\Auth\GoogleAuthController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/auth/google/redirect', [GoogleAuthController::class, 'redirect'])->name('auth.google.redirect');
Route::get('/auth/google/callback', [GoogleAuthController::class, 'callback'])->name('auth.google.callback');

// Stripe Checkout'un success_url/cancel_url'i. Asıl abonelik uzatma işi
// webhook'ta olur (bkz. SubscriptionCheckoutController::webhook) — bu
// sayfalar yalnızca kullanıcıya görsel bir kapanış veriyor VE mobil
// uygulamanın WebView'i bu adrese gelindiğini görünce ekranı kapatıp
// abonelik durumunu tazeliyor. Kimlik doğrulaması yok: Stripe'ın
// yönlendirdiği tarayıcı, oturumumuzu taşımaz.
Route::get('/odeme/sonuc/basarili', function () {
    return view('odeme.basarili');
})->name('odeme.basarili');

Route::get('/odeme/sonuc/basarisiz', function () {
    return view('odeme.basarisiz');
})->name('odeme.basarisiz');
