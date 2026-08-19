<?php

namespace App\Filament\App\Resources\IncomeEntries\Tables;

use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class IncomeEntriesTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('date', 'desc')
            ->columns([
                TextColumn::make('date')
                    ->label('Tarih')
                    ->dateTime('d.m.Y')
                    ->sortable(),
                TextColumn::make('description')
                    ->label('Açıklama')
                    ->weight(FontWeight::SemiBold)
                    ->searchable(),
                TextColumn::make('customer.display_name')
                    ->label('Müşteri'),
                TextColumn::make('category')
                    ->label('Kategori')
                    ->badge(),
                TextColumn::make('amount_minor')
                    ->label('Tutar')
                    ->color('success')
                    ->formatStateUsing(fn (?int $state) => '+'.number_format(($state ?? 0) / 100, 2, ',', '.').' ₺'),
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
