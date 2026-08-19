<?php

namespace App\Filament\App\Resources\Proformas\Tables;

use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Support\Carbon;

class ProformasTable
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
                TextColumn::make('valid_until')
                    ->label('Geçerlilik')
                    ->date('d.m.Y')
                    ->placeholder('—')
                    ->color(fn (?Carbon $state) => $state?->isPast() ? 'danger' : null),
                TextColumn::make('total_minor')
                    ->label('Tutar')
                    ->formatStateUsing(fn (?int $state) => number_format(($state ?? 0) / 100, 2, ',', '.').' ₺'),
                TextColumn::make('created_at')
                    ->label('Tarih')
                    ->dateTime('d.m.Y')
                    ->sortable(),
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
