<?php

namespace App\Filament\App\Resources\IncomeEntries\Schemas;

use App\Models\Customer;
use App\Models\Job;
use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

class IncomeEntryForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Tahsilat Bilgileri')
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
                                'Servis Geliri' => 'Servis Geliri',
                                'Ürün Satışı' => 'Ürün Satışı',
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
                        Select::make('customer_id')
                            ->label('Müşteri')
                            ->options(fn () => Customer::query()->get()->pluck('display_name', 'id'))
                            ->searchable(),
                        Select::make('job_id')
                            ->label('İlgili İş')
                            ->options(fn () => Job::query()->pluck('title', 'id'))
                            ->searchable(),
                        Textarea::make('note')
                            ->label('Not')
                            ->columnSpanFull(),
                    ]),
            ]);
    }
}
