<?php

declare(strict_types=1);

namespace App\Filament\Widgets;

use App\Models\AppLog;
use App\Models\Company;
use App\Models\PaymentRequest;
use App\Models\User;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

/**
 * Panele girer girmez görülen özet.
 *
 * Seçim ölçütü: her kutu ya bir KARAR ya da bir MÜDAHALE gerektirmeli.
 * "Toplam kayıt" gibi yalnızca büyüyen sayılar bilinçli olarak dışarıda —
 * onlar iyi hissettirir ama hiçbir soruyu cevaplamaz.
 */
class IsletmeOzetiWidget extends StatsOverviewWidget
{
    protected static ?int $sort = 1;

    protected ?string $pollingInterval = '60s';

    /**
     * Özet sayılar.
     *
     * Bilinçli olarak sade Eloquent sayımları: tek bir `filter (where ...)`
     * sorgusu PostgreSQL'de çalışıyor ama test veritabanında (SQLite)
     * patlıyordu. Bir gösterge widget'ının veritabanı motoruna bağımlı
     * olması, testlerde asla doğrulanamaması demek — ve bu panel canlıda
     * bir kez tam da doğrulanmamış bir Filament çağrısı yüzünden kırıldı.
     *
     * Maliyeti önemsiz: birkaç yüz satırlık bir tabloda beş sayım.
     */
    private function companyCounts(): object
    {
        $now = now();

        return (object) [
            'aktif' => Company::query()
                ->where('is_active', true)
                ->where('subscription_expires_at', '>', $now)
                ->count(),
            'suresi_dolmus' => Company::query()
                ->where('subscription_expires_at', '<=', $now)
                ->count(),
            'yakinda_bitecek' => Company::query()
                ->whereBetween('subscription_expires_at', [$now, $now->copy()->addDays(7)])
                ->count(),
            'yeni' => Company::query()
                ->where('created_at', '>=', $now->copy()->subDays(30))
                ->count(),
        ];
    }

    protected function getStats(): array
    {
        $company = $this->companyCounts();

        $bekleyenOdeme = PaymentRequest::query()->where('status', 'PENDING')->count();

        $sonGunHata = AppLog::query()
            ->whereIn('level', ['error', 'critical', 'alert', 'emergency'])
            ->where('created_at', '>=', now()->subDay())
            ->count();

        return [
            Stat::make('Aktif işletme', (string) ($company->aktif ?? 0))
                ->description(($company->yeni ?? 0).' tanesi son 30 günde katıldı')
                ->descriptionIcon('heroicon-m-arrow-trending-up')
                ->chart($this->sonYediGunKayit())
                ->color('success'),

            Stat::make('Süresi dolmuş', (string) ($company->suresi_dolmus ?? 0))
                ->description(($company->yakinda_bitecek ?? 0).' işletmenin süresi 7 gün içinde bitiyor')
                ->descriptionIcon('heroicon-m-clock')
                ->color(($company->yakinda_bitecek ?? 0) > 0 ? 'warning' : 'gray'),

            Stat::make('Bekleyen ödeme', (string) $bekleyenOdeme)
                ->description($bekleyenOdeme > 0 ? 'Onayınızı bekliyor' : 'Bekleyen talep yok')
                ->descriptionIcon('heroicon-m-banknotes')
                ->color($bekleyenOdeme > 0 ? 'warning' : 'gray'),

            Stat::make('Kullanıcı', (string) User::query()->count())
                ->description('Tüm işletmelerdeki toplam hesap')
                ->descriptionIcon('heroicon-m-users')
                ->color('gray'),

            Stat::make('Son 24 saat hata', (string) $sonGunHata)
                ->description($sonGunHata > 0 ? 'Sistem günlüğünü inceleyin' : 'Hata kaydı yok')
                ->descriptionIcon($sonGunHata > 0 ? 'heroicon-m-exclamation-triangle' : 'heroicon-m-check-circle')
                ->color($sonGunHata > 0 ? 'danger' : 'success'),
        ];
    }

    /**
     * Kutunun içindeki mini grafik — son 7 günün günlük kayıt sayısı.
     * Sayının kendisi kadar YÖNÜ de önemli.
     *
     * Gruplama PHP tarafında yapılıyor: tarih fonksiyonlarının adı
     * veritabanı motoruna göre değişiyor ve widget'ın taşınabilir kalması
     * bu ölçekte performanstan daha değerli.
     */
    private function sonYediGunKayit(): array
    {
        $sayaclar = Company::query()
            ->where('created_at', '>=', now()->subDays(7)->startOfDay())
            ->pluck('created_at')
            ->countBy(fn ($tarih) => $tarih->toDateString());

        $chart = [];
        for ($i = 6; $i >= 0; $i--) {
            $chart[] = (int) ($sayaclar[now()->subDays($i)->toDateString()] ?? 0);
        }

        return $chart;
    }
}
