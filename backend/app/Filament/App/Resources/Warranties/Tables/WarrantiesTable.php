<?php

namespace App\Filament\App\Resources\Warranties\Tables;

use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Support\Carbon;

class WarrantiesTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('warranty_expires_at', 'desc')
            ->columns([
                TextColumn::make('customer.display_name')
                    ->label('Müşteri')
                    ->weight(FontWeight::SemiBold)
                    ->searchable(),
                TextColumn::make('item_description')
                    ->label('Ürün/Hizmet')
                    ->searchable(),
                TextColumn::make('install_date')
                    ->label('Montaj')
                    ->date('d.m.Y')
                    ->sortable(),
                TextColumn::make('warranty_expires_at')
                    ->label('Garanti Bitiş')
                    ->date('d.m.Y')
                    ->sortable()
                    ->badge()
                    ->color(fn (Carbon $state) => $state->isPast() ? 'danger' : ($state->diffInDays(now()) <= 30 ? 'warning' : 'success')),
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
