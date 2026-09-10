<?php

namespace App\Filament\App\Resources\Personnel\Schemas;

use App\Models\User;
use App\Support\RolePermissions;
use Filament\Facades\Filament;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Illuminate\Support\Facades\Hash;

class PersonnelForm
{
    /** Rol kodları -> ekranda görünen ad. */
    private const ROL_ETIKETLERI = [
        RolePermissions::OWNER => 'Sahip',
        RolePermissions::ADMIN => 'Yönetici',
        RolePermissions::TECHNICIAN => 'Teknisyen',
        RolePermissions::ACCOUNTING => 'Muhasebe',
        RolePermissions::VIEWER => 'Salt Okunur',
    ];

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
                        // Seçenekler RolePermissions::ASSIGNABLE'dan geliyor:
                        // OWNER burada BİLEREK yok. Eskiden listede duruyordu
                        // ve panelde hiçbir yetki kontrolü olmadığı için
                        // herhangi bir personel kendine "Sahip" hesabı
                        // açabiliyordu. API tarafı (StorePersonnelRequest)
                        // baştan beri aynı listeyi kullanıyordu.
                        Select::make('role')
                            ->label('Yetki')
                            ->options(fn (?User $record): array => collect(
                                $record?->role === RolePermissions::OWNER
                                    ? [RolePermissions::OWNER, ...RolePermissions::ASSIGNABLE]
                                    : RolePermissions::ASSIGNABLE
                            )->mapWithKeys(fn (string $rol): array => [
                                $rol => self::ROL_ETIKETLERI[$rol],
                            ])->all())
                            ->default(RolePermissions::TECHNICIAN)
                            ->required()
                            ->native(false)
                            // Kişi kendi rolünü değiştiremez — yetki
                            // yükseltmenin en kısa yolu bu. Son sahibin
                            // rolü de düşürülemez (bkz. UserPolicy).
                            ->disabled(fn (?User $record): bool => $record !== null
                                && ! Filament::auth()->user()->can('changeRole', $record))
                            ->dehydrated(fn (?User $record): bool => $record === null
                                || Filament::auth()->user()->can('changeRole', $record)),
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
