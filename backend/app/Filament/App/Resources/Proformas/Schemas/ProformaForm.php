<?php

namespace App\Filament\App\Resources\Proformas\Schemas;

use App\Filament\App\Resources\Quotes\Schemas\QuoteForm;
use App\Models\Customer;
use Filament\Forms\Components\DatePicker;
use Filament\Forms\Components\Repeater;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

class ProformaForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Proforma Bilgileri')
                    ->columns(2)
                    ->components([
                        Select::make('customer_id')
                            ->label('Müşteri')
                            ->options(fn () => Customer::query()->get()->pluck('display_name', 'id'))
                            ->searchable()
                            ->required(),
                        DatePicker::make('valid_until')
                            ->label('Geçerlilik Tarihi')
                            ->native(false),
                        Textarea::make('notes')
                            ->label('Notlar')
                            ->columnSpanFull(),
                    ]),
                Section::make('Kalemler')
                    ->components([
                        Repeater::make('items')
                            ->label('')
                            ->schema(QuoteForm::itemSchema())
                            ->columns(6)
                            ->defaultItems(1)
                            ->addActionLabel('Kalem Ekle')
                            ->reorderable(false),
                    ]),
            ]);
    }
}
