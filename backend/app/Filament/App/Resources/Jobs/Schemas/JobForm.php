<?php

namespace App\Filament\App\Resources\Jobs\Schemas;

use App\Models\Customer;
use App\Models\JobType;
use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

class JobForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('İş Bilgileri')
                    ->columns(2)
                    ->components([
                        Select::make('customer_id')
                            ->label('Müşteri')
                            ->options(fn () => Customer::query()->get()->pluck('display_name', 'id'))
                            ->searchable()
                            ->required(),
                        Select::make('job_type_id')
                            ->label('İş Tipi')
                            ->options(fn () => JobType::query()->pluck('name', 'id'))
                            ->searchable(),
                        TextInput::make('title')
                            ->label('Başlık')
                            ->required()
                            ->maxLength(255)
                            ->columnSpanFull(),
                        Textarea::make('description')
                            ->label('Açıklama')
                            ->columnSpanFull(),
                        Textarea::make('address')
                            ->label('Adres')
                            ->columnSpanFull(),
                    ]),
                Section::make('Planlama')
                    ->columns(2)
                    ->components([
                        DateTimePicker::make('appointment_date')
                            ->label('Randevu Tarihi')
                            ->native(false),
                        Select::make('priority')
                            ->label('Öncelik')
                            ->options([
                                'YUKSEK' => 'Yüksek',
                                'NORMAL' => 'Normal',
                                'DUSUK' => 'Düşük',
                            ])
                            ->default('NORMAL')
                            ->required()
                            ->native(false),
                        Select::make('status')
                            ->label('Durum')
                            ->options([
                                'TALEP' => 'Talep',
                                'PLANLANDI' => 'Planlandı',
                                'DEVAM_EDIYOR' => 'Devam Ediyor',
                                'BEKLEMEDE' => 'Beklemede',
                                'TAMAMLANDI' => 'Tamamlandı',
                                'IPTAL' => 'İptal',
                            ])
                            ->default('TALEP')
                            ->required()
                            ->native(false),
                    ]),
                Section::make('Fiyat')
                    ->columns(2)
                    ->components([
                        TextInput::make('estimated_price_minor')
                            ->label('Tahmini Tutar (₺)')
                            ->numeric()
                            ->prefix('₺')
                            ->afterStateHydrated(fn ($component, $state) => $component->state($state !== null ? $state / 100 : null))
                            ->dehydrateStateUsing(fn ($state) => $state !== null && $state !== '' ? (int) round($state * 100) : null),
                        TextInput::make('actual_price_minor')
                            ->label('Gerçekleşen Tutar (₺)')
                            ->numeric()
                            ->prefix('₺')
                            ->afterStateHydrated(fn ($component, $state) => $component->state($state !== null ? $state / 100 : null))
                            ->dehydrateStateUsing(fn ($state) => $state !== null && $state !== '' ? (int) round($state * 100) : null),
                        Textarea::make('notes')
                            ->label('Notlar')
                            ->columnSpanFull(),
                    ]),
            ]);
    }
}
