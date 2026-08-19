<?php

namespace App\Filament\App\Resources\Jobs\Tables;

use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class JobsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('code')
                    ->label('Kod')
                    ->searchable(),
                TextColumn::make('title')
                    ->label('Başlık')
                    ->weight(FontWeight::SemiBold)
                    ->searchable(),
                TextColumn::make('customer.display_name')
                    ->label('Müşteri')
                    ->searchable(),
                TextColumn::make('status')
                    ->label('Durum')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'TAMAMLANDI' => 'success',
                        'IPTAL' => 'danger',
                        'DEVAM_EDIYOR' => 'warning',
                        default => 'gray',
                    }),
                TextColumn::make('priority')
                    ->label('Öncelik')
                    ->badge()
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('appointment_date')
                    ->label('Randevu')
                    ->dateTime('d.m.Y H:i')
                    ->sortable(),
            ])
            ->filters([
                SelectFilter::make('status')
                    ->label('Durum')
                    ->options([
                        'TALEP' => 'Talep',
                        'PLANLANDI' => 'Planlandı',
                        'DEVAM_EDIYOR' => 'Devam Ediyor',
                        'BEKLEMEDE' => 'Beklemede',
                        'TAMAMLANDI' => 'Tamamlandı',
                        'IPTAL' => 'İptal',
                    ]),
            ])
            ->recordActions([
                EditAction::make(),
                DeleteAction::make(),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                ]),
            ]);
    }
}
