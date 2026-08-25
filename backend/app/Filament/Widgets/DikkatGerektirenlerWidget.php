<?php

declare(strict_types=1);

namespace App\Filament\Widgets;

use App\Filament\Resources\Companies\CompanyResource;
use App\Models\Company;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget;

/**
 * Aboneliği bitmiş ya da bitmek üzere olan işletmeler.
 *
 * Panelin ana sayfasında bir LİSTE olmasının sebebi: özet sayılar "10
 * işletmenin süresi doluyor" der ama kimin doluyor, ne zaman arayacağım
 * sorusunu cevaplamaz. Buradan doğrudan işletme kaydına geçilebilir.
 */
class DikkatGerektirenlerWidget extends TableWidget
{
    protected static ?int $sort = 3;

    protected int|string|array $columnSpan = 'full';

    protected static ?string $heading = 'Dikkat gerektiren abonelikler';

    public function table(Table $table): Table
    {
        return $table
            ->query(
                Company::query()
                    ->with('plan')
                    // Süresi dolmuş ya da 7 gün içinde dolacak olanlar.
                    ->where('subscription_expires_at', '<=', now()->addDays(7))
                    ->orderBy('subscription_expires_at')
            )
            ->columns([
                TextColumn::make('name')
                    ->label('İşletme')
                    ->weight(FontWeight::SemiBold)
                    ->description(fn (Company $record) => $record->plan?->name ?? 'Plan atanmamış')
                    ->searchable(),

                TextColumn::make('subscription_expires_at')
                    ->label('Bitiş')
                    ->date('d.m.Y')
                    ->description(fn (Company $record) => $record->subscription_expires_at?->diffForHumans())
                    ->sortable(),

                TextColumn::make('durum')
                    ->label('Durum')
                    ->badge()
                    ->state(fn (Company $record) => match (true) {
                        ! $record->is_active => 'Askıya alınmış',
                        $record->subscription_expires_at?->isPast() => 'Süresi dolmuş',
                        default => 'Bitmek üzere',
                    })
                    ->color(fn (string $state) => match ($state) {
                        'Askıya alınmış' => 'gray',
                        'Süresi dolmuş' => 'danger',
                        default => 'warning',
                    }),

                TextColumn::make('users_count')
                    ->label('Kullanıcı')
                    ->counts('users')
                    ->alignCenter()
                    ->toggleable(),
            ])
            ->recordUrl(fn (Company $record) => CompanyResource::getUrl('index', [
                'tableSearch' => $record->name,
            ]))
            ->emptyStateHeading('Bekleyen bir şey yok')
            ->emptyStateDescription(
                'Yaklaşan ya da dolmuş abonelik yok — müdahale gerektiren '
                .'bir durum bulunmuyor.'
            )
            ->paginated([5, 10, 25]);
    }

    /**
     * Aynı sayfada birden fazla tablo olduğunda sıralama/sayfalama
     * durumlarının birbirine karışmaması için ayrı bir anahtar.
     */
    protected function getTableQueryStringIdentifier(): ?string
    {
        return 'dikkat';
    }
}
