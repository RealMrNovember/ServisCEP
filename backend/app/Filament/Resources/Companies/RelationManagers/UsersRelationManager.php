<?php

declare(strict_types=1);

namespace App\Filament\Resources\Companies\RelationManagers;

use App\Support\RolePermissions;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

/**
 * Şirketin kullanıcıları — destek/iletişim için salt okunur liste.
 *
 * Kasıtlı olarak SALT OKUNUR: kullanıcı ekleme/silme işletme sahibinin
 * kendi panelinden (veya mobil uygulamadan) yapılır. Süper-admin'in
 * müşterinin personelini buradan değiştirmesi, sahibinin haberi olmadan
 * yetki değiştirmek anlamına gelirdi.
 */
class UsersRelationManager extends RelationManager
{
    protected static string $relationship = 'users';

    protected static ?string $title = 'Kullanıcılar';

    protected static string|\BackedEnum|null $icon = 'heroicon-o-users';

    public function table(Table $table): Table
    {
        return $table
            ->recordTitleAttribute('full_name')
            ->defaultSort('role')
            ->columns([
                TextColumn::make('full_name')
                    ->label('Ad Soyad')
                    ->weight(FontWeight::SemiBold)
                    ->searchable(),
                TextColumn::make('email')
                    ->label('E-posta')
                    ->copyable()
                    ->copyMessage('E-posta kopyalandı')
                    ->searchable(),
                TextColumn::make('phone')
                    ->label('Telefon')
                    ->placeholder('—')
                    ->copyable(),
                TextColumn::make('role')
                    ->label('Rol')
                    ->badge()
                    ->formatStateUsing(fn (?string $state) => RolePermissions::label((string) $state))
                    ->color(fn (?string $state) => $state === RolePermissions::OWNER ? 'success' : 'gray'),
                TextColumn::make('created_at')
                    ->label('Kayıt')
                    ->dateTime('d.m.Y')
                    ->toggleable(isToggledHiddenByDefault: true),
            ]);
    }
}
