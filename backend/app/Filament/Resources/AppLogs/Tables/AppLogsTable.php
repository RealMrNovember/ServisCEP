<?php

declare(strict_types=1);

namespace App\Filament\Resources\AppLogs\Tables;

use App\Models\AppLog;
use Filament\Actions\Action;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\Filter;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Filament\Forms\Components\DatePicker;
use Illuminate\Support\HtmlString;

class AppLogsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn ($query) => $query->with(['user', 'company']))
            ->defaultSort('created_at', 'desc')
            // Günlük sürekli akar; otomatik tazeleme olmadan panel yanıltıcı
            // biçimde "sakin" görünüyor.
            ->poll('30s')
            ->columns([
                TextColumn::make('created_at')
                    ->label('Zaman')
                    ->dateTime('d.m.Y H:i:s')
                    ->description(fn (AppLog $record) => $record->created_at?->diffForHumans())
                    ->sortable(),

                TextColumn::make('level')
                    ->label('Seviye')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => mb_strtoupper($state, 'UTF-8'))
                    ->color(fn (string $state) => AppLog::levelColor($state))
                    ->sortable(),

                TextColumn::make('source')
                    ->label('Kaynak')
                    ->badge()
                    ->color('gray')
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        AppLog::SOURCE_SERVER => 'Sunucu',
                        AppLog::SOURCE_REQUEST => 'İstek',
                        AppLog::SOURCE_MOBILE => 'Mobil',
                        default => $state,
                    })
                    ->sortable(),

                TextColumn::make('message')
                    ->label('Olay')
                    ->weight(FontWeight::Medium)
                    ->wrap()
                    ->searchable()
                    ->description(fn (AppLog $record) => self::endpointLabel($record)),

                TextColumn::make('status')
                    ->label('Durum')
                    ->badge()
                    ->color(fn (?int $state) => match (true) {
                        $state === null => 'gray',
                        $state >= 500 => 'danger',
                        $state >= 400 => 'warning',
                        default => 'success',
                    })
                    ->placeholder('—')
                    ->sortable()
                    ->toggleable(),

                TextColumn::make('duration_ms')
                    ->label('Süre')
                    ->formatStateUsing(fn (?int $state) => $state === null ? '—' : "$state ms")
                    ->color(fn (?int $state) => $state !== null && $state >= 3000 ? 'warning' : null)
                    ->sortable()
                    ->toggleable(),

                TextColumn::make('user.full_name')
                    ->label('Kullanıcı')
                    ->placeholder('—')
                    ->description(fn (AppLog $record) => $record->company?->name)
                    ->searchable()
                    ->toggleable(),

                TextColumn::make('app_version')
                    ->label('Sürüm')
                    ->badge()
                    ->color('gray')
                    ->placeholder('—')
                    ->sortable()
                    ->toggleable(),

                TextColumn::make('platform')
                    ->label('Platform')
                    ->placeholder('—')
                    ->toggleable(isToggledHiddenByDefault: true),

                TextColumn::make('ip')
                    ->label('IP')
                    ->placeholder('—')
                    ->copyable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                SelectFilter::make('level')
                    ->label('Seviye')
                    ->multiple()
                    ->options([
                        'critical' => 'Kritik',
                        'error' => 'Hata',
                        'warning' => 'Uyarı',
                        'info' => 'Bilgi',
                        'debug' => 'Ayrıntı',
                    ]),

                SelectFilter::make('source')
                    ->label('Kaynak')
                    ->options([
                        AppLog::SOURCE_SERVER => 'Sunucu',
                        AppLog::SOURCE_REQUEST => 'İstek',
                        AppLog::SOURCE_MOBILE => 'Mobil',
                    ]),

                SelectFilter::make('app_version')
                    ->label('Uygulama sürümü')
                    ->options(fn () => AppLog::query()
                        ->whereNotNull('app_version')
                        ->distinct()
                        ->orderByDesc('app_version')
                        ->pluck('app_version', 'app_version')
                        ->all()),

                Filter::make('tarih')
                    ->schema([
                        DatePicker::make('baslangic')->label('Başlangıç'),
                        DatePicker::make('bitis')->label('Bitiş'),
                    ])
                    ->query(fn ($query, array $data) => $query
                        ->when($data['baslangic'] ?? null, fn ($q, $date) => $q->whereDate('created_at', '>=', $date))
                        ->when($data['bitis'] ?? null, fn ($q, $date) => $q->whereDate('created_at', '<=', $date))),
            ])
            ->recordActions([
                Action::make('ayrinti')
                    ->label('Ayrıntı')
                    ->icon('heroicon-o-magnifying-glass')
                    ->modalHeading(fn (AppLog $record) => $record->message)
                    ->modalSubmitAction(false)
                    ->modalCancelActionLabel('Kapat')
                    ->modalContent(fn (AppLog $record) => new HtmlString(self::detailHtml($record))),
            ])
            ->emptyStateHeading('Kayıt yok')
            ->emptyStateDescription(
                'Seçili filtrelerde günlük kaydı bulunmuyor. Sistem sessizse '
                .'bu iyi haberdir.'
            );
    }

    /** Tablo satırının altındaki ikincil bilgi: hangi uca ne oldu. */
    private static function endpointLabel(AppLog $record): ?string
    {
        if (blank($record->path)) {
            return null;
        }

        return trim(($record->method ?? '').' '.$record->path);
    }

    /**
     * Ayrıntı penceresi.
     *
     * Bağlam JSON'u ham hâliyle gösterilir — teşhis sırasında aranan şey
     * çoğu zaman "Google ne dedi", "istisna hangi satırda" gibi ayrıntılar
     * oluyor ve bunları özetlemek bilgi kaybettiriyor.
     */
    private static function detailHtml(AppLog $record): string
    {
        $rows = [
            'Zaman' => $record->created_at?->format('d.m.Y H:i:s'),
            'Seviye' => mb_strtoupper($record->level, 'UTF-8'),
            'Kaynak' => $record->source,
            'Uç' => self::endpointLabel($record),
            'Durum' => $record->status,
            'Süre' => $record->duration_ms !== null ? $record->duration_ms.' ms' : null,
            'Kullanıcı' => $record->user?->full_name,
            'İşletme' => $record->company?->name,
            'Platform' => $record->platform,
            'Uygulama sürümü' => $record->app_version,
            'Cihaz' => $record->device,
            'IP' => $record->ip,
        ];

        $html = '<dl class="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">';
        foreach ($rows as $label => $value) {
            if (blank($value)) {
                continue;
            }
            $html .= '<div class="min-w-0">'
                .'<dt class="text-xs font-medium text-gray-500 dark:text-gray-400">'.e($label).'</dt>'
                .'<dd class="mt-0.5 text-sm break-words text-gray-950 dark:text-white">'.e((string) $value).'</dd>'
                .'</div>';
        }
        $html .= '</dl>';

        if (filled($record->context)) {
            $json = json_encode(
                $record->context,
                JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES,
            );

            $html .= '<div class="mt-5">'
                .'<div class="mb-2 text-xs font-medium text-gray-500 dark:text-gray-400">Ayrıntı</div>'
                .'<pre class="max-h-96 overflow-auto rounded-lg bg-gray-950/5 p-3 text-xs leading-relaxed '
                .'whitespace-pre-wrap break-words dark:bg-white/5">'.e((string) $json).'</pre>'
                .'</div>';
        }

        return $html;
    }
}
