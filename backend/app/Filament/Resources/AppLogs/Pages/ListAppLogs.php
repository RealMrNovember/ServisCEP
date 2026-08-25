<?php

declare(strict_types=1);

namespace App\Filament\Resources\AppLogs\Pages;

use App\Filament\Resources\AppLogs\AppLogResource;
use App\Models\AppLog;
use Filament\Resources\Pages\ListRecords;
use Filament\Schemas\Components\Tabs\Tab;

class ListAppLogs extends ListRecords
{
    protected static string $resource = AppLogResource::class;

    protected function getHeaderActions(): array
    {
        return [];
    }

    /**
     * Sekmeler, en sık sorulan üç soruyu tek tıkla cevaplar: "bir sorun
     * var mı", "kim giremiyor", "hangi cihazda patlıyor". Filtre menüsünü
     * açmak zorunda kalmadan.
     */
    public function getTabs(): array
    {
        return [
            'hatalar' => Tab::make('Hatalar')
                ->badge(fn () => AppLog::query()
                    ->whereIn('level', ['error', 'critical', 'alert', 'emergency'])
                    ->where('created_at', '>=', now()->subDay())
                    ->count() ?: null)
                ->badgeColor('danger')
                ->modifyQueryUsing(fn ($query) => $query->whereIn(
                    'level',
                    ['error', 'critical', 'alert', 'emergency'],
                )),

            'mobil' => Tab::make('Mobil')
                ->modifyQueryUsing(fn ($query) => $query->where(
                    'source',
                    AppLog::SOURCE_MOBILE,
                )),

            'istekler' => Tab::make('İstekler')
                ->modifyQueryUsing(fn ($query) => $query->where(
                    'source',
                    AppLog::SOURCE_REQUEST,
                )),

            'hepsi' => Tab::make('Hepsi'),
        ];
    }

    public function getDefaultActiveTab(): string
    {
        return 'hatalar';
    }
}
