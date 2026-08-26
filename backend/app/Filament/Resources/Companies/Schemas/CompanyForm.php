<?php

namespace App\Filament\Resources\Companies\Schemas;

use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

class CompanyForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Şirket Bilgileri')
                    ->columns(2)
                    ->components([
                        TextInput::make('name')
                            ->label('Şirket Adı')
                            ->required()
                            ->columnSpanFull(),
                        TextInput::make('iban')
                            ->label('IBAN'),
                        Textarea::make('business_types')
                            ->label('İşletme Türleri')
                            ->required()
                            ->default('')
                            ->columnSpanFull(),
                    ]),

                Section::make('Abonelik')
                    ->description('Paket, süre ve erişim durumu — ödeme onaylandığında otomatik güncellenir, burada da elle düzenlenebilir.')
                    ->columns(2)
                    ->components([
                        Select::make('plan_id')
                            ->label('Paket')
                            ->relationship('plan', 'name')
                            ->searchable()
                            ->preload(),
                        DateTimePicker::make('subscription_expires_at')
                            ->label('Abonelik Bitiş Tarihi')
                            ->helperText('Boş bırakılırsa süresiz kabul edilir.')
                            ->native(false),
                        Toggle::make('is_active')
                            ->label('Aktif')
                            ->helperText('Kapatılırsa, süre dolmamış olsa bile şirket erişimi engellenir.')
                            ->required()
                            ->default(true),
                        Textarea::make('admin_note')
                            ->label('Admin Notu')
                            ->columnSpanFull(),
                    ]),
            ]);
    }
}
