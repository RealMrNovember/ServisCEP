<?php

namespace App\Filament\App\Resources\Warranties\Schemas;

use App\Models\Customer;
use App\Models\Job;
use App\Models\Product;
use Filament\Forms\Components\DatePicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

class WarrantyForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Garanti Bilgileri')
                    ->columns(2)
                    ->components([
                        Select::make('customer_id')
                            ->label('Müşteri')
                            ->options(fn () => Customer::query()->get()->pluck('display_name', 'id'))
                            ->searchable()
                            ->required(),
                        Select::make('product_id')
                            ->label('Ürün (stoktan)')
                            ->options(fn () => Product::query()->pluck('name', 'id'))
                            ->searchable(),
                        Select::make('job_id')
                            ->label('İlgili İş')
                            ->options(fn () => Job::query()->pluck('title', 'id'))
                            ->searchable(),
                        TextInput::make('item_description')
                            ->label('Monte Edilen Ürün/Hizmet')
                            ->required()
                            ->maxLength(255)
                            ->columnSpanFull(),
                        TextInput::make('serial_number')
                            ->label('Seri No'),
                        DatePicker::make('install_date')
                            ->label('Montaj Tarihi')
                            ->native(false)
                            ->default(now())
                            ->required(),
                        TextInput::make('warranty_months')
                            ->label('Garanti Süresi (ay)')
                            ->numeric()
                            ->default(12)
                            ->required(),
                        Textarea::make('notes')
                            ->label('Notlar')
                            ->columnSpanFull(),
                    ]),
            ]);
    }
}
