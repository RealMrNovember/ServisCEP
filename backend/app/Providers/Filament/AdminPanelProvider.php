<?php

namespace App\Providers\Filament;

use Filament\Http\Middleware\Authenticate;
use Filament\Http\Middleware\AuthenticateSession;
use Filament\Http\Middleware\DisableBladeIconComponents;
use Filament\Http\Middleware\DispatchServingFilamentEvent;
use Filament\Navigation\NavigationGroup;
use Filament\Pages\Dashboard;
use Filament\Panel;
use Filament\PanelProvider;
use Filament\Support\Colors\Color;
use Filament\Support\Enums\Width;
use Filament\Support\Icons\Heroicon;
use Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse;
use Illuminate\Cookie\Middleware\EncryptCookies;
use Illuminate\Foundation\Http\Middleware\PreventRequestForgery;
use Illuminate\Routing\Middleware\SubstituteBindings;
use Illuminate\Session\Middleware\StartSession;
use Illuminate\View\Middleware\ShareErrorsFromSession;

class AdminPanelProvider extends PanelProvider
{
    public function panel(Panel $panel): Panel
    {
        return $panel
            ->default()
            ->id('admin')
            ->path('admin')
            ->brandName('TeknikCEP Admin')
            ->authGuard('admin')
            ->login()
            // Adminler şifrelerini e-postayla kendileri sıfırlayabilsin —
            // seed anında bir kez gösterilen şifreye bağımlılığı kaldırır
            // (SMTP canlıda yapılandırıldı, 2026-08-22).
            ->passwordReset()
            ->authPasswordBroker('admin_users')
            ->viteTheme('resources/css/filament/admin/theme.css')
            ->colors([
                'primary' => Color::Blue,
            ])
            ->discoverResources(in: app_path('Filament/Resources'), for: 'App\Filament\Resources')
            ->discoverPages(in: app_path('Filament/Pages'), for: 'App\Filament\Pages')
            ->pages([
                Dashboard::class,
            ])
            ->discoverWidgets(in: app_path('Filament/Widgets'), for: 'App\Filament\Widgets')
            // Varsayılan Filament tanıtım kutusu (FilamentInfoWidget)
            // bilinçli olarak kaldırıldı: panelin ana sayfası işletmeye
            // dair göstergeler için var, kullanılan çatının reklamı için
            // değil. Kendi widget'larımız `discoverWidgets` ile bulunur.
            ->widgets([])
            // Menü grupları — kaynak sayısı arttıkça düz liste
            // gezinilemez hâle geliyordu.
            ->navigationGroups([
                NavigationGroup::make('Yönetim')
                    ->icon(Heroicon::OutlinedBuildingOffice2),
                NavigationGroup::make('Abonelik')
                    ->icon(Heroicon::OutlinedCreditCard),
                NavigationGroup::make('Sistem')
                    ->icon(Heroicon::OutlinedCog6Tooth),
            ])
            // Geniş ekranda içerik ortada dar bir sütuna sıkışıyordu;
            // günlük ve şirket tabloları yatay alanı gerçekten kullanıyor.
            ->maxContentWidth(Width::Full)
            ->sidebarCollapsibleOnDesktop()
            ->globalSearchKeyBindings(['command+k', 'ctrl+k'])
            ->middleware([
                EncryptCookies::class,
                AddQueuedCookiesToResponse::class,
                StartSession::class,
                AuthenticateSession::class,
                ShareErrorsFromSession::class,
                PreventRequestForgery::class,
                SubstituteBindings::class,
                DisableBladeIconComponents::class,
                DispatchServingFilamentEvent::class,
            ])
            ->authMiddleware([
                Authenticate::class,
            ]);
    }
}
