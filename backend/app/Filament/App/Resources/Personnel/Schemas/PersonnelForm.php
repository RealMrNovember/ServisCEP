<?php

namespace App\Filament\App\Resources\Personnel\Schemas;

use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Illuminate\Support\Facades\Hash;

class PersonnelForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Personel Bilgileri')
                    ->columns(2)
                    ->components([
                        TextInput::make('full_name')
                            ->label('Ad Soyad')
                            ->required()
                            ->maxLength(255),
                        TextInput::make('email')
                            ->label('E-posta')
                            ->email()
                            ->required()
                            ->unique(ignoreRecord: true)
                            ->maxLength(255),
                        TextInput::make('phone')
                            ->label('Telefon')
                            ->tel()
                            ->maxLength(255),
                        Select::make('role')
                            ->label('Yetki')
                            ->options([
                                'OWNER' => 'Sahip',
                                'ADMIN' => 'Yönetici',
                                'TECHNICIAN' => 'Teknisyen',
                                'ACCOUNTING' => 'Muhasebe',
                                'VIEWER' => 'Salt Okunur',
                            ])
                            ->default('TECHNICIAN')
                            ->required()
                            ->native(false),
                        TextInput::make('password')
                            ->label(fn (string $operation) => $operation === 'create' ? 'Şifre' : 'Yeni Şifre')
                            ->password()
                            ->revealable()
                            ->required(fn (string $operation) => $operation === 'create')
                            ->helperText(fn (string $operation) => $operation === 'edit' ? 'Boş bırakılırsa şifre değişmez.' : null)
                            ->dehydrated(fn (?string $state) => filled($state))
                            ->dehydrateStateUsing(fn (string $state) => Hash::make($state))
                            ->maxLength(255),
                    ]),
            ]);
    }
}
