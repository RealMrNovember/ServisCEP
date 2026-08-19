<?php

namespace App\Filament\App\Resources\ExpenseEntries\Schemas;

use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

class ExpenseEntryForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Gider Bilgileri')
                    ->columns(2)
                    ->components([
                        TextInput::make('description')
                            ->label('Açıklama')
                            ->required()
                            ->maxLength(255)
                            ->columnSpanFull(),
                        DateTimePicker::make('date')
                            ->label('Tarih')
                            ->native(false)
                            ->default(now())
                            ->required(),
                        TextInput::make('amount_minor')
                            ->label('Tutar (₺)')
                            ->numeric()
                            ->prefix('₺')
                            ->required()
                            ->afterStateHydrated(fn ($component, $state) => $component->state($state !== null ? $state / 100 : null))
                            ->dehydrateStateUsing(fn ($state) => (int) round(((float) ($state ?? 0)) * 100)),
                        Select::make('category')
                            ->label('Kategori')
                            ->options([
                                'Malzeme' => 'Malzeme',
                                'Kira' => 'Kira',
                                'Fatura' => 'Fatura',
                                'Personel' => 'Personel',
                                'Diğer' => 'Diğer',
                            ])
                            ->default('Diğer')
                            ->native(false),
                        Select::make('method')
                            ->label('Ödeme Yöntemi')
                            ->options([
                                'Nakit' => 'Nakit',
                                'Kart' => 'Kart',
                                'Havale/EFT' => 'Havale/EFT',
                            ])
                            ->default('Nakit')
                            ->native(false),
                        TextInput::make('vendor_name')
                            ->label('Tedarikçi / Satıcı')
                            ->maxLength(255),
                        Textarea::make('note')
                            ->label('Not')
                            ->columnSpanFull(),
                    ]),
            ]);
    }
}
