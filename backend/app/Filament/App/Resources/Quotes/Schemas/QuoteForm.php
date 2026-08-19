<?php

namespace App\Filament\App\Resources\Quotes\Schemas;

use App\Models\Customer;
use Filament\Forms\Components\Repeater;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

class QuoteForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Teklif Bilgileri')
                    ->columns(2)
                    ->components([
                        Select::make('customer_id')
                            ->label('Müşteri')
                            ->options(fn () => Customer::query()->get()->pluck('display_name', 'id'))
                            ->searchable()
                            ->required(),
                        Select::make('status')
                            ->label('Durum')
                            ->options([
                                'TASLAK' => 'Taslak',
                                'GONDERILDI' => 'Gönderildi',
                                'BEKLEMEDE' => 'Beklemede',
                                'KABUL_EDILDI' => 'Kabul Edildi',
                                'REDDEDILDI' => 'Reddedildi',
                                'SURESI_DOLDU' => 'Süresi Doldu',
                            ])
                            ->default('TASLAK')
                            ->required()
                            ->native(false),
                        Textarea::make('notes')
                            ->label('Notlar')
                            ->columnSpanFull(),
                    ]),
                Section::make('Kalemler')
                    ->components([
                        Repeater::make('items')
                            ->label('')
                            ->schema(self::itemSchema())
                            ->columns(6)
                            ->defaultItems(1)
                            ->addActionLabel('Kalem Ekle')
                            ->reorderable(false),
                    ]),
            ]);
    }

    public static function itemSchema(): array
    {
        return [
            TextInput::make('description')
                ->label('Açıklama')
                ->required()
                ->columnSpan(2),
            TextInput::make('quantity')
                ->label('Miktar')
                ->numeric()
                ->default(1)
                ->required(),
            TextInput::make('unit')
                ->label('Birim')
                ->default('adet'),
            TextInput::make('unit_price_minor')
                ->label('Birim Fiyat (₺)')
                ->numeric()
                ->required()
                ->afterStateHydrated(fn ($component, $state) => $component->state($state !== null ? $state / 100 : null))
                ->dehydrateStateUsing(fn ($state) => (int) round(((float) ($state ?? 0)) * 100)),
            TextInput::make('tax_rate')
                ->label('KDV (%)')
                ->numeric()
                ->default(20)
                ->required(),
            TextInput::make('discount_minor')
                ->label('İskonto (₺)')
                ->numeric()
                ->default(0)
                ->afterStateHydrated(fn ($component, $state) => $component->state($state !== null ? $state / 100 : null))
                ->dehydrateStateUsing(fn ($state) => (int) round(((float) ($state ?? 0)) * 100)),
        ];
    }
}
