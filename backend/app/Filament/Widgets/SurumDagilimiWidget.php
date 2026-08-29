<?php

declare(strict_types=1);

namespace App\Filament\Widgets;

use App\Http\Controllers\Api\V1\AppVersionController;
use App\Models\User;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

/**
 * Kim uygulamayı gerçekten kullanıyor ve hangi sürümde.
 *
 * NEDEN VAR: bu soruların cevabı Play Console'da aranıyordu ve orada
 * yok. Play'in "uygulamayı yükleyen kullanıcı sayısı" sütunu günlerce
 * gecikiyor, test kanallarını güvenilir saymıyor ve kimin hangi sürümde
 * kaldığını hiç söylemiyor. Oysa bu bilginin tamamı BİZDE: uygulama her
 * istekte sürümünü ve son görülme zamanını yazıyor
 * (bkz. LogApiRequests::recordClientInfo).
 *
 * "Kurdu" değil "AÇTI" sayılıyor: kurulup hiç açılmamış bir uygulama
 * kullanıcı değildir ve o ayrımı Play hiç göstermiyor.
 */
class SurumDagilimiWidget extends StatsOverviewWidget
{
    protected static ?int $sort = 2;

    protected ?string $pollingInterval = '60s';

    protected function getStats(): array
    {
        $simdi = now();
        $guncelYapi = AppVersionController::currentBuild();
        $guncelSurum = AppVersionController::currentVersion();

        // Sade sayımlar: koşullu toplama (filter/case) SQLite'ta
        // patlıyordu ve bu panel canlıda bir kez tam da doğrulanmamış
        // bir çağrı yüzünden kırıldı (bkz. IsletmeOzetiWidget).
        $toplam = User::query()->count();

        $hicAcmamis = User::query()->whereNull('last_seen_at')->count();

        $aktif7 = User::query()
            ->where('last_seen_at', '>=', $simdi->copy()->subDays(7))
            ->count();

        $aktif30 = User::query()
            ->where('last_seen_at', '>=', $simdi->copy()->subDays(30))
            ->count();

        $guncelde = User::query()->where('app_build', '>=', $guncelYapi)->count();

        $eskide = User::query()
            ->whereNotNull('app_build')
            ->where('app_build', '<', $guncelYapi)
            ->count();

        // Hangi yapıda kaç kişi — en yaygın üçü.
        $dagilim = User::query()
            ->selectRaw('app_version, app_build, count(*) as adet')
            ->whereNotNull('app_build')
            ->groupBy('app_version', 'app_build')
            ->orderByDesc('adet')
            ->limit(3)
            ->get()
            ->map(fn ($s) => sprintf(
                '%s (%d): %d kişi',
                $s->app_version ?? '?',
                $s->app_build,
                $s->adet,
            ))
            ->all();

        return [
            Stat::make('Uygulamayı açan', (string) ($toplam - $hicAcmamis))
                ->description($toplam.' kayıtlı kullanıcının')
                ->descriptionIcon('heroicon-m-device-phone-mobile')
                ->color($hicAcmamis > 0 ? 'warning' : 'success'),

            Stat::make('Son 7 günde aktif', (string) $aktif7)
                ->description('30 günde: '.$aktif30)
                ->descriptionIcon('heroicon-m-signal')
                ->color($aktif7 > 0 ? 'success' : 'gray'),

            Stat::make('Güncel sürümde', $guncelde.' / '.($guncelde + $eskide))
                ->description(
                    $eskide > 0
                        ? $eskide.' kişi eski sürümde — '.$guncelSurum.' bekliyor'
                        : 'Herkes '.$guncelSurum.' sürümünde'
                )
                ->descriptionIcon(
                    $eskide > 0
                        ? 'heroicon-m-exclamation-triangle'
                        : 'heroicon-m-check-circle'
                )
                ->color($eskide > 0 ? 'warning' : 'success'),

            Stat::make('Sürüm dağılımı', (string) count($dagilim))
                ->description(
                    $dagilim === []
                        ? 'Henüz sürüm bilgisi gelmedi'
                        : implode(' · ', $dagilim)
                )
                ->descriptionIcon('heroicon-m-rectangle-stack')
                ->color('gray'),
        ];
    }
}
