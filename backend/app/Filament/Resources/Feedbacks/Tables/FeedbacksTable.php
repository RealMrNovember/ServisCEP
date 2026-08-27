<?php

namespace App\Filament\Resources\Feedbacks\Tables;

use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class FeedbacksTable
{
    public static function configure(Table $table): Table
    {
        return $table
            // Yeniden eskiye: bekleyen bir soru, cevaplanmış bir sorudan
            // daha aciledir ve en üstte durmalı.
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('created_at')
                    ->label('Tarih')
                    ->dateTime('d.m.Y H:i')
                    ->sortable(),

                TextColumn::make('company.name')
                    ->label('Şirket')
                    ->weight(FontWeight::SemiBold)
                    ->searchable(),

                TextColumn::make('user.full_name')
                    ->label('Gönderen')
                    ->searchable(),

                TextColumn::make('type')
                    ->label('Tür')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        'ONERI' => 'Öneri',
                        'HATA' => 'Hata',
                        'SORU' => 'Soru',
                        default => 'Diğer',
                    })
                    ->color(fn (string $state) => match ($state) {
                        'HATA' => 'danger',
                        'ONERI' => 'success',
                        'SORU' => 'info',
                        default => 'gray',
                    }),

                // Mesajın ilk satırı listede görünür: adine her kaydı
                // açmadan neyin ne olduğunu görebilmeli.
                TextColumn::make('message')
                    ->label('Mesaj')
                    ->limit(60)
                    ->tooltip(fn ($record) => $record->message)
                    ->searchable()
                    ->wrap(),

                TextColumn::make('status')
                    ->label('Durum')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        'YENI' => 'Yeni',
                        'INCELENIYOR' => 'İnceleniyor',
                        'YANITLANDI' => 'Yanıtlandı',
                        default => 'Kapandı',
                    })
                    ->color(fn (string $state) => match ($state) {
                        'YENI' => 'warning',
                        'INCELENIYOR' => 'info',
                        'YANITLANDI' => 'success',
                        default => 'gray',
                    }),

                TextColumn::make('app_version')
                    ->label('Sürüm')
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                SelectFilter::make('status')
                    ->label('Durum')
                    ->options([
                        'YENI' => 'Yeni',
                        'INCELENIYOR' => 'İnceleniyor',
                        'YANITLANDI' => 'Yanıtlandı',
                        'KAPANDI' => 'Kapandı',
                    ]),
                SelectFilter::make('type')
                    ->label('Tür')
                    ->options([
                        'ONERI' => 'Öneri',
                        'HATA' => 'Hata',
                        'SORU' => 'Soru',
                        'DIGER' => 'Diğer',
                    ]),
            ]);
    }
}
