<?php

namespace App\Providers;

use Illuminate\Support\Facades\URL;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Cloudflare terminates TLS and proxies to the origin over plain
        // HTTP, so Laravel would otherwise generate http:// URLs (Livewire
        // requests, asset links) even though the site is only ever served
        // over HTTPS — causing mixed-content errors in the browser.
        if ($this->app->environment('production')) {
            URL::forceScheme('https');
        }
    }
}
