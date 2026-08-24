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
