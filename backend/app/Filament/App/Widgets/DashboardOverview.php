<?php

namespace App\Filament\App\Widgets;

use App\Models\ExpenseEntry;
use App\Models\IncomeEntry;
use App\Models\Job;
use Filament\Support\Icons\Heroicon;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Illuminate\Support\Carbon;

class DashboardOverview extends StatsOverviewWidget
{
    protected static ?int $sort = 1;

    protected function getStats(): array
    {
        $monthStart = Carbon::now()->startOfMonth();
        $monthEnd = Carbon::now()->endOfMonth();

        $incomeMinor = IncomeEntry::query()
            ->whereBetween('date', [$monthStart, $monthEnd])
            ->sum('amount_minor');

        $expenseMinor = ExpenseEntry::query()
            ->whereBetween('date', [$monthStart, $monthEnd])
            ->sum('amount_minor');

        $profitMinor = $incomeMinor - $expenseMinor;

        $pendingJobsCount = Job::query()
            ->whereNotIn('status', ['TAMAMLANDI', 'IPTAL'])
            ->count();

        return [
            Stat::make('Bu Ayki Gelir', $this->formatMinor($incomeMinor))
                ->description(Carbon::now()->translatedFormat('F Y'))
                ->descriptionIcon(Heroicon::OutlinedArrowTrendingUp)
                ->color('success'),
            Stat::make('Bu Ayki Gider', $this->formatMinor($expenseMinor))
                ->description(Carbon::now()->translatedFormat('F Y'))
                ->descriptionIcon(Heroicon::OutlinedArrowTrendingDown)
                ->color('danger'),
            Stat::make('Bu Ayki Kâr', $this->formatMinor($profitMinor))
                ->description($profitMinor >= 0 ? 'Pozitif' : 'Negatif')
                ->descriptionIcon($profitMinor >= 0 ? Heroicon::OutlinedCheckCircle : Heroicon::OutlinedExclamationTriangle)
                ->color($profitMinor >= 0 ? 'success' : 'danger'),
            Stat::make('Bekleyen İşler', (string) $pendingJobsCount)
                ->description('Tamamlanmamış iş/talep sayısı')
                ->descriptionIcon(Heroicon::OutlinedWrenchScrewdriver)
                ->color($pendingJobsCount > 0 ? 'warning' : 'success'),
        ];
    }

    private function formatMinor(int $minor): string
    {
        return number_format($minor / 100, 2, ',', '.').' ₺';
    }
}
