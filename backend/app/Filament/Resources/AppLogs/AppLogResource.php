<?php

declare(strict_types=1);

namespace App\Filament\Resources\AppLogs;

use App\Filament\Resources\AppLogs\Pages\ListAppLogs;
use App\Filament\Resources\AppLogs\Tables\AppLogsTable;
use App\Models\AppLog;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;

/**
 * Sistem günlüğü — sunucu, istek ve mobil kaynaklı olaylar tek ekranda.
 *
 * Var olma sebebi: bir arızayı teşhis etmek için sunucuya SSH ile girip
 * `laravel.log` okumak zorunda kalmamak. Mobil taraftaki hatalar zaten
 * hiçbir yere ulaşmıyordu.
 *
 * Yalnızca OKUNUR: günlük kaydı düzenlenebilir olsaydı kanıt değerini
 * yitirirdi. Temizlik `logs:prune` komutuyla, saklama süresine göre
 * otomatik yapılır.
 */
class AppLogResource extends Resource
{
    protected static ?string $model = AppLog::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedClipboardDocumentList;

    protected static ?string $navigationLabel = 'Sistem günlüğü';

    protected static ?string $modelLabel = 'Günlük kaydı';

    protected static ?string $pluralModelLabel = 'Sistem günlüğü';

    protected static string|\UnitEnum|null $navigationGroup = 'Sistem';

    protected static ?int $navigationSort = 1;

    protected static ?string $recordTitleAttribute = 'message';

    public static function table(Table $table): Table
    {
        return AppLogsTable::configure($table);
    }

    /**
     * Son 24 saatteki hata sayısı menüde rozet olarak görünür — panele
     * girer girmez "bir şeyler ters mi" sorusunun cevabı.
     */
    public static function getNavigationBadge(): ?string
    {
        $count = AppLog::query()
            ->whereIn('level', ['error', 'critical', 'alert', 'emergency'])
            ->where('created_at', '>=', now()->subDay())
            ->count();

        return $count > 0 ? (string) $count : null;
    }

    public static function getNavigationBadgeColor(): ?string
    {
        return 'danger';
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function getPages(): array
    {
        return [
            'index' => ListAppLogs::route('/'),
        ];
    }
}
