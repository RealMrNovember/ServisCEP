<?php

namespace App\Filament\App\Resources\Personnel\Tables;

use App\Models\User;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Facades\Filament;
use Filament\Notifications\Notification;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class PersonnelTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('full_name')
                    ->label('Ad Soyad')
                    ->weight(FontWeight::SemiBold)
                    ->searchable(),
                TextColumn::make('email')
                    ->label('E-posta')
                    ->searchable(),
                TextColumn::make('phone')
                    ->label('Telefon'),
                TextColumn::make('role')
                    ->label('Yetki')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        'OWNER' => 'Sahip',
                        'ADMIN' => 'Yönetici',
                        'TECHNICIAN' => 'Teknisyen',
                        'ACCOUNTING' => 'Muhasebe',
                        'VIEWER' => 'Salt Okunur',
                        default => $state,
                    }),
                TextColumn::make('created_at')
                    ->label('Eklenme Tarihi')
                    ->dateTime('d.m.Y')
                    ->sortable(),
            ])
            ->recordActions([
                EditAction::make(),
                DeleteAction::make()
                    ->visible(fn (User $record) => $record->id !== Filament::auth()->id())
                    ->before(function (User $record, DeleteAction $action) {
                        if (User::where('company_id', $record->company_id)->count() <= 1) {
                            Notification::make()
                                ->title('Şirketin son kullanıcısı silinemez')
                                ->danger()
                                ->send();

                            $action->cancel();
                        }
                    }),
            ]);
    }
}
