<?php

declare(strict_types=1);

namespace App\Filament\Widgets;

use App\Models\Company;
use App\Models\User;
use Filament\Widgets\ChartWidget;

/**
 * Son 30 günün günlük kayıt eğrisi.
 *
 * Tek bir "toplam" sayısı, işlerin hızlandığını mı yavaşladığını mı
 * söylemez. Kapalı test döneminde asıl sorulan soru bu: testçi kazanımı
 * devam ediyor mu, durdu mu.
 */
class BuyumeGrafigiWidget extends ChartWidget
{
    protected ?string $heading = 'Son 30 gün';

    protected ?string $description = 'Günlük yeni işletme ve kullanıcı kaydı';

    protected static ?int $sort = 2;

    protected int|string|array $columnSpan = 'full';

    protected ?string $pollingInterval = null;

    protected function getType(): string
    {
        return 'line';
    }

    /**
     * @return \Illuminate\Support\Collection<string, int> tarih => adet
     *
     * Gruplama PHP'de: `date(created_at)` gibi ifadelerin davranışı
     * veritabanı motoruna göre değişiyor ve widget testlerde (SQLite)
     * patlıyordu.
     */
    private function gunlukSayim(string $model)
    {
        return $model::query()
            ->where('created_at', '>=', now()->subDays(29)->startOfDay())
            ->pluck('created_at')
            ->countBy(fn ($tarih) => $tarih->toDateString());
    }

    protected function getData(): array
    {
        $companies = $this->gunlukSayim(Company::class);
        $users = $this->gunlukSayim(User::class);

        $labels = [];
        $companySeries = [];
        $userSeries = [];

        for ($i = 29; $i >= 0; $i--) {
            $day = now()->subDays($i);
            $key = $day->toDateString();

            $labels[] = $day->translatedFormat('j M');
            $companySeries[] = (int) ($companies[$key] ?? 0);
            $userSeries[] = (int) ($users[$key] ?? 0);
        }

        return [
            'datasets' => [
                [
                    'label' => 'İşletme',
                    'data' => $companySeries,
                    'borderColor' => '#2563eb',
                    'backgroundColor' => 'rgba(37, 99, 235, 0.12)',
                    'fill' => true,
                    'tension' => 0.35,
                ],
                [
                    'label' => 'Kullanıcı',
                    'data' => $userSeries,
                    'borderColor' => '#16a34a',
                    'backgroundColor' => 'rgba(22, 163, 74, 0.10)',
                    'fill' => true,
                    'tension' => 0.35,
                ],
            ],
            'labels' => $labels,
        ];
    }

    /**
     * Kayıt sayıları küçük tam sayılar; eksende 0.5 gibi ara değerler
     * göstermek grafiği yanıltıcı kılıyordu.
     */
    protected function getOptions(): array
    {
        return [
            'scales' => [
                'y' => [
                    'beginAtZero' => true,
                    'ticks' => ['precision' => 0],
                ],
            ],
            'plugins' => [
                'legend' => ['position' => 'bottom'],
            ],
            'maintainAspectRatio' => false,
        ];
    }
}
