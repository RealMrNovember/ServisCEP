<?php

namespace App\Filament\App\Resources\Quotes\Tables;

use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class QuotesTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('code')
                    ->label('Kod')
                    ->searchable(),
                TextColumn::make('customer.display_name')
                    ->label('Müşteri')
                    ->weight(FontWeight::SemiBold)
                    ->searchable(),
                TextColumn::make('status')
                    ->label('Durum')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'KABUL_EDILDI' => 'success',
                        'REDDEDILDI', 'SURESI_DOLDU' => 'danger',
                        'GONDERILDI', 'BEKLEMEDE' => 'warning',
                        default => 'gray',
                    }),
                TextColumn::make('total_minor')
                    ->label('Tutar')
                    ->formatStateUsing(fn (?int $state) => number_format(($state ?? 0) / 100, 2, ',', '.').' ₺'),
                TextColumn::make('created_at')
                    ->label('Tarih')
                    ->dateTime('d.m.Y')
                    ->sortable(),
            ])
            ->filters([
                SelectFilter::make('status')
                    ->label('Durum')
                    ->options([
                        'TASLAK' => 'Taslak',
                        'GONDERILDI' => 'Gönderildi',
                        'BEKLEMEDE' => 'Beklemede',
                        'KABUL_EDILDI' => 'Kabul Edildi',
                        'REDDEDILDI' => 'Reddedildi',
                        'SURESI_DOLDU' => 'Süresi Doldu',
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
