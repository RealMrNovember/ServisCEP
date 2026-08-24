<?php

declare(strict_types=1);

namespace App\Filament\Resources\Users;

use App\Filament\Resources\Users\Pages\ListUsers;
use App\Filament\Resources\Users\Tables\UsersTable;
use App\Models\User;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;

/**
 * Tüm kiracı kullanıcıları — süper-admin görünümü.
 *
 * Amaç: destek müdahalesi. Örneğin kişi yanlışlıkla kendi şirketini
 * açtıysa, çalıştığı firmaya taşınması buradan yapılır (e-posta global
 * benzersiz olduğu için firma sahibi onu personel olarak ekleyemez).
 *
 * Kasıtlı olarak "oluşturma" YOK: kullanıcı ya kendi kayıt olur ya da
 * işletme sahibi kendi panelinden ekler. Admin'in sessizce hesap açması
 * hesap sahipliğini bulanıklaştırırdı.
 */
class UserResource extends Resource
{
    protected static ?string $model = User::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedUsers;

    protected static ?string $navigationLabel = 'Kullanıcılar';

    protected static ?string $modelLabel = 'Kullanıcı';

    protected static ?string $pluralModelLabel = 'Kullanıcılar';

    protected static ?int $navigationSort = 2;

    protected static ?string $recordTitleAttribute = 'full_name';

    public static function table(Table $table): Table
    {
        return UsersTable::configure($table);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListUsers::route('/'),
        ];
    }
}
