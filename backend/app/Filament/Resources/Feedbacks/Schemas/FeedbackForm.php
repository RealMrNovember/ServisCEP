<?php

namespace App\Filament\Resources\Feedbacks\Schemas;

use Filament\Forms\Components\Placeholder;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Schemas\Schema;

class FeedbackForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Placeholder::make('kim')
                    ->label('Gönderen')
                    ->content(fn ($record) => sprintf(
                        '%s / %s',
                        $record?->company?->name ?? '-',
                        $record?->user?->full_name ?? 'Silinmiş kullanıcı',
                    )),

                Placeholder::make('kunye')
                    ->label('Sürüm / cihaz')
                    ->content(fn ($record) => trim(sprintf(
                        '%s %s %s',
                        $record?->app_version ?? '-',
                        $record?->platform ?? '',
                        $record?->device ?? '',
                    ))),

                Select::make('type')
                    ->label('Tür')
                    ->options([
                        'ONERI' => 'Öneri',
                        'HATA' => 'Hata',
                        'SORU' => 'Soru',
                        'DIGER' => 'Diğer',
                    ])
                    ->disabled(),

                // Mesaj DEĞİŞTİRİLEMEZ: kullanıcının yazdığı şey kayıttır.
                Textarea::make('message')
                    ->label('Mesaj')
                    ->rows(6)
                    ->disabled()
                    ->columnSpanFull(),

                Select::make('status')
                    ->label('Durum')
                    ->options([
                        'YENI' => 'Yeni',
                        'INCELENIYOR' => 'İnceleniyor',
                        'YANITLANDI' => 'Yanıtlandı',
                        'KAPANDI' => 'Kapandı',
                    ])
                    ->required(),

                Textarea::make('reply')
                    ->label('Yanıt')
                    // Kullanıcı bunu uygulamada GÖRECEK ve kaydedildiğinde
                    // bildirim alacak.
                    ->helperText('Kaydettiğinizde kullanıcıya bildirim gider ve yanıt uygulamada görünür.')
                    ->rows(5)
                    ->columnSpanFull(),

                Placeholder::make('replied_at')
                    ->label('Yanıt tarihi')
                    ->content(fn ($record) => $record?->replied_at?->translatedFormat('d F Y H:i') ?? 'Henüz yanıtlanmadı'),
            ]);
    }
}
