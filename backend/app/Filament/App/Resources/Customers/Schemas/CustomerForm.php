<?php

namespace App\Filament\App\Resources\Customers\Schemas;

use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Illuminate\Support\Facades\Auth;

class CustomerForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Müşteri Bilgileri')
                    ->description('Yetkili adı soyadı ve firma adından en az biri girilmelidir.')
                    ->columns(2)
                    ->components([
                        TextInput::make('contact_name')
                            ->label('Yetkili Adı Soyadı')
                            ->requiredWithout('company_name')
                            ->maxLength(255),
                        TextInput::make('company_name')
                            ->label('Firma Adı')
                            ->requiredWithout('contact_name')
                            ->maxLength(255),
                        Select::make('type')
                            ->label('Müşteri Tipi')
                            ->options([
                                'BIREYSEL' => 'Bireysel',
                                'FIRMA' => 'Firma',
                                'APARTMAN' => 'Apartman',
                                'SITE' => 'Site',
                                'KAMU' => 'Kamu',
                                'DIGER' => 'Diğer',
                            ])
                            ->default('BIREYSEL')
                            ->required()
                            ->native(false),
                        TextInput::make('phone')
                            ->label('Telefon')
                            ->tel()
                            ->maxLength(255),
                        TextInput::make('email')
                            ->label('E-posta')
                            ->email()
                            ->maxLength(255),
                        TextInput::make('iban')
                            ->label('IBAN')
                            ->maxLength(255),
                    ]),
                Section::make('Adres')
                    ->columns(2)
                    ->components([
                        Textarea::make('address')
                            ->label('Adres')
                            ->columnSpanFull(),
                        TextInput::make('il')
                            ->label('İl')
                            ->maxLength(255),
                        TextInput::make('ilce')
                            ->label('İlçe')
                            ->maxLength(255),
                    ]),
                Section::make('Diğer')
                    ->columns(2)
                    ->components([
                        TextInput::make('tax_info')
                            ->label('Vergi Bilgisi')
                            ->maxLength(255),
                        TextInput::make('tags')
                            ->label('Etiketler')
                            ->maxLength(255),
                        FileUpload::make('tax_certificate_path')
                            ->label('Vergi Levhası')
                            ->disk('local')
                            ->directory(fn () => 'tax-certificates/'.Auth::user()->company_id)
                            ->acceptedFileTypes(['application/pdf', 'image/jpeg', 'image/png'])
                            ->maxSize(10240)
                            ->columnSpanFull(),
                        Textarea::make('notes')
                            ->label('Notlar')
                            ->columnSpanFull(),
                    ]),
            ]);
    }
}
