<?php

namespace App\Filament\Resources\PaymentRequests\Tables;

use App\Models\AdminUser;
use App\Models\PaymentRequest;
use Filament\Actions\Action;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Notifications\Notification;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class PaymentRequestsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('company.name')
                    ->label('Şirket')
                    ->weight(FontWeight::SemiBold)
                    ->searchable(),
                TextColumn::make('requestedBy.full_name')
                    ->label('Gönderen'),
                TextColumn::make('plan.name')
                    ->label('Talep edilen paket')
                    ->badge()
                    ->placeholder('—'),
                TextColumn::make('claimed_amount_minor')
                    ->label('Beyan edilen tutar')
                    ->formatStateUsing(fn ($state) => $state === null ? '—' : number_format($state / 100, 2, ',', '.').' ₺'),
                TextColumn::make('customer_note')
                    ->label('Müşteri notu')
                    ->limit(40)
                    ->wrap(),
                TextColumn::make('status')
                    ->label('Durum')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        'PENDING' => 'Bekliyor',
                        'APPROVED' => 'Onaylandı',
                        'REJECTED' => 'Reddedildi',
                        default => $state,
                    })
                    ->color(fn (string $state) => match ($state) {
                        'PENDING' => 'warning',
                        'APPROVED' => 'success',
                        'REJECTED' => 'danger',
                        default => 'gray',
                    }),
                TextColumn::make('created_at')
                    ->label('Talep Tarihi')
                    ->dateTime('d.m.Y H:i')
                    ->sortable(),
            ])
            ->filters([
                SelectFilter::make('status')
                    ->label('Durum')
                    ->options([
                        'PENDING' => 'Bekliyor',
                        'APPROVED' => 'Onaylandı',
                        'REJECTED' => 'Reddedildi',
                    ])
                    ->default('PENDING'),
            ])
            ->recordActions([
                Action::make('approve')
                    ->label('Onayla')
                    ->icon('heroicon-o-check-circle')
                    ->color('success')
                    ->visible(fn (PaymentRequest $record) => $record->status === 'PENDING')
                    ->requiresConfirmation()
                    ->schema([
                        Select::make('duration')
                            ->label('Aktivasyon Süresi')
                            ->options(['MONTHLY' => '1 Ay', 'YEARLY' => '1 Yıl'])
                            ->required()
                            ->native(false),
                        Textarea::make('note')
                            ->label('Not (opsiyonel)'),
                    ])
                    ->action(function (PaymentRequest $record, array $data): void {
                        /** @var AdminUser $admin */
                        $admin = auth('admin')->user();
                        $record->approve($data['duration'], $admin, $data['note'] ?? null);

                        Notification::make()
                            ->title('Ödeme onaylandı, abonelik güncellendi')
                            ->success()
                            ->send();
                    }),
                Action::make('reject')
                    ->label('Reddet')
                    ->icon('heroicon-o-x-circle')
                    ->color('danger')
                    ->visible(fn (PaymentRequest $record) => $record->status === 'PENDING')
                    ->requiresConfirmation()
                    ->schema([
                        Textarea::make('note')
                            ->label('Red gerekçesi (opsiyonel)'),
                    ])
                    ->action(function (PaymentRequest $record, array $data): void {
                        /** @var AdminUser $admin */
                        $admin = auth('admin')->user();
                        $record->reject($admin, $data['note'] ?? null);

                        Notification::make()
                            ->title('Talep reddedildi')
                            ->send();
                    }),
            ]);
    }
}
