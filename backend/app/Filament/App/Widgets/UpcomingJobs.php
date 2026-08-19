<?php

namespace App\Filament\App\Widgets;

use App\Models\Job;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget;

class UpcomingJobs extends TableWidget
{
    protected static ?int $sort = 2;

    protected int|string|array $columnSpan = 'full';

    public function table(Table $table): Table
    {
        return $table
            ->heading('Bekleyen İşler')
            ->query(
                Job::query()
                    ->whereNotIn('status', ['TAMAMLANDI', 'IPTAL'])
                    ->orderBy('appointment_date')
            )
            ->columns([
                TextColumn::make('code')
                    ->label('Kod'),
                TextColumn::make('title')
                    ->label('Başlık')
                    ->weight(FontWeight::SemiBold)
                    ->searchable(),
                TextColumn::make('customer.display_name')
                    ->label('Müşteri'),
                TextColumn::make('status')
                    ->label('Durum')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        'TALEP' => 'Talep',
                        'PLANLANDI' => 'Planlandı',
                        'DEVAM_EDIYOR' => 'Devam Ediyor',
                        'BEKLEMEDE' => 'Beklemede',
                        default => $state,
                    })
                    ->color(fn (string $state) => match ($state) {
                        'DEVAM_EDIYOR' => 'warning',
                        'BEKLEMEDE' => 'danger',
                        default => 'gray',
                    }),
                TextColumn::make('appointment_date')
                    ->label('Randevu')
                    ->dateTime('d.m.Y H:i')
                    ->placeholder('—'),
            ])
            ->paginated([5, 10, 25])
            ->defaultPaginationPageOption(5)
            ->emptyStateHeading('Bekleyen iş yok')
            ->emptyStateDescription('Tüm işleriniz tamamlanmış görünüyor.');
    }
}
