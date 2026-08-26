<?php

namespace App\Filament\App\Resources\Products\Schemas;

use Filament\Forms\Components\TextInput;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

class ProductForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Ürün Bilgileri')
                    ->columns(2)
                    ->components([
                        TextInput::make('name')
                            ->label('Ürün Adı')
                            ->required()
                            ->maxLength(255)
                            ->columnSpanFull(),
                        TextInput::make('barcode')
                            ->label('Barkod')
                            ->maxLength(255),
                        TextInput::make('sku')
                            ->label('Stok Kodu (SKU)')
                            ->maxLength(255),
                        TextInput::make('brand')
                            ->label('Marka')
                            ->maxLength(255),
                        TextInput::make('model')
                            ->label('Model')
                            ->maxLength(255),
                        TextInput::make('category')
                            ->label('Kategori')
                            ->maxLength(255),
                        TextInput::make('unit')
                            ->label('Birim')
                            ->default('adet')
                            ->maxLength(255),
                    ]),
                Section::make('Fiyat ve Stok')
                    ->columns(2)
                    ->components([
                        TextInput::make('purchase_price_minor')
                            ->label('Alış Fiyatı (₺)')
                            ->numeric()
                            ->prefix('₺')
                            ->afterStateHydrated(fn ($component, $state) => $component->state($state !== null ? $state / 100 : null))
                            ->dehydrateStateUsing(fn ($state) => (int) round(((float) ($state ?? 0)) * 100)),
                        TextInput::make('sale_price_minor')
                            ->label('Satış Fiyatı (₺)')
                            ->numeric()
                            ->prefix('₺')
                            ->afterStateHydrated(fn ($component, $state) => $component->state($state !== null ? $state / 100 : null))
                            ->dehydrateStateUsing(fn ($state) => (int) round(((float) ($state ?? 0)) * 100)),
                        TextInput::make('current_stock')
                            ->label('Mevcut Stok')
                            ->numeric()
                            ->default(0)
                            ->required(),
                        TextInput::make('min_stock')
                            ->label('Minimum Stok')
                            ->numeric()
                            ->default(0)
                            ->helperText('Stok bu seviyenin altına düşünce listede uyarı gösterilir.'),
                    ]),
            ]);
    }
}
