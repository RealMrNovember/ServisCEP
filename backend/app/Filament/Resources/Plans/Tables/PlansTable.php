<?php

namespace App\Filament\Resources\Plans\Tables;

use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class PlansTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('sort_order')
            ->columns([
                TextColumn::make('name')
                    ->label('Paket Adı')
                    ->weight(FontWeight::SemiBold)
                    ->searchable(),
                TextColumn::make('price_minor')
                    ->label('Fiyat')
                    ->formatStateUsing(fn ($state) => number_format($state / 100, 2, ',', '.').' ₺')
                    ->sortable(),
                TextColumn::make('duration_days')
                    ->label('Süre (gün)')
                    ->numeric()
                    ->sortable(),
                TextColumn::make('max_users')
                    ->label('Maks. kullanıcı')
                    ->placeholder('Sınırsız')
                    ->numeric()
                    ->sortable(),
                TextColumn::make('companies_count')
                    ->label('Aktif şirket')
                    ->counts('companies'),
                IconColumn::make('is_active')
                    ->label('Satışta')
                    ->boolean(),
            ])
            ->recordActions([
                EditAction::make(),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                ]),
            ]);
    }
}
