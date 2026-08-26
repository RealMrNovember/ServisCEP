<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Bkz. ROADMAP.md § B10 — geri dönüşüm kutusu günlük temizliği.
Schedule::command('customers:purge-trash')->daily();

// Abonelik hatırlatma push'u — sabah 10:00'da, makul bir saatte
// (gece yarısı bildirim göndermek kullanıcıyı rahatsız eder).
Schedule::command('subscriptions:notify-expiring')->dailyAt('10:00');

// Uygulama günlüğü budaması.
//
// HAFTALIK çalışır ve saklama süreleri geniştir (bilgi 30, hata 180 gün).
// Günlük ve dar pencereli bir budama, seyrek ortaya çıkan bir arızanın
// kanıtını daha fark edilmeden siliyordu. Pazar gecesi 03:40 — haftanın
// en sakin saati.
Schedule::command('logs:prune')->weeklyOn(0, '03:40');

// Alan izleri yalnızca çakışma çözümünde kullanılıyor; kayıt
// senkronlandıktan sonra ölü ağırlık. Budama veri kaybettirmez —
// iz eksikse birleştirme reddedilir ve çakışma insana gider.
Schedule::command('sync:prune-field-changes')->weeklyOn(0, '03:50');
