<?php

namespace App\Filament\Resources\Companies\Tables;

use App\Models\Company;
use Filament\Actions\Action;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Notifications\Notification;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use Illuminate\Support\Carbon;

class CompaniesTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('name')
                    ->label('Şirket')
                    ->weight(FontWeight::SemiBold)
                    ->searchable(),
                TextColumn::make('plan.name')
                    ->label('Paket')
                    ->badge()
                    ->searchable(),
                TextColumn::make('subscription_expires_at')
                    ->label('Abonelik Bitişi')
                    ->dateTime('d.m.Y H:i')
                    ->placeholder('Süresiz')
                    ->color(fn (?Carbon $state) => $state === null ? 'gray' : ($state->isPast() ? 'danger' : ($state->diffInDays(now()) <= 3 ? 'warning' : 'success')))
                    ->sortable(),
                IconColumn::make('is_active')
                    ->label('Aktif')
                    ->boolean(),
                TextColumn::make('users_count')
                    ->label('Kullanıcı')
                    ->counts('users'),
                TextColumn::make('created_at')
                    ->label('Kayıt Tarihi')
                    ->dateTime('d.m.Y')
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                TernaryFilter::make('is_active')->label('Aktif mi'),
            ])
            ->recordActions([
                Action::make('extend')
                    ->label('Süre Uzat')
                    ->icon('heroicon-o-clock')
                    ->color('success')
                    ->schema([
                        Select::make('duration')
                            ->label('Süre')
                            ->options(['MONTHLY' => '1 Ay', 'YEARLY' => '1 Yıl'])
                            ->required()
                            ->native(false),
                    ])
                    ->action(function (Company $record, array $data): void {
                        $base = $record->subscription_expires_at?->isFuture()
                            ? $record->subscription_expires_at
                            : Carbon::now();

                        $record->subscription_expires_at = $data['duration'] === 'YEARLY'
                            ? $base->copy()->addYear()
                            : $base->copy()->addMonth();
                        $record->is_active = true;
                        $record->save();

                        Notification::make()
                            ->title('Abonelik uzatıldı')
                            ->success()
                            ->send();
                    }),
                EditAction::make(),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                ]),
            ]);
    }
}
