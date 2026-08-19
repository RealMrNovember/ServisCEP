<?php

namespace App\Filament\Resources\PaymentRequests\Tables;

use App\Models\AdminUser;
use App\Models\PaymentRequest;
use App\Models\Plan;
use Filament\Actions\Action;
use Filament\Forms\Components\Placeholder;
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
                TextColumn::make('approvedPlan.name')
                    ->label('Onaylanan paket')
                    ->badge()
                    ->color('success')
                    ->placeholder('—'),
                TextColumn::make('requested_duration')
                    ->label('Talep Edilen Süre')
                    ->formatStateUsing(fn (?string $state) => match ($state) {
                        'MONTHLY' => 'Aylık',
                        'YEARLY' => 'Yıllık',
                        default => '—',
                    }),
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
                    ->schema(fn (PaymentRequest $record) => [
                        Placeholder::make('summary')
                            ->label('Talep Özeti')
                            ->content(sprintf(
                                'Talep edilen paket: %s  ·  Talep edilen süre: %s  ·  Beyan edilen tutar: %s%s',
                                $record->plan?->name ?? 'Belirtilmemiş',
                                match ($record->requested_duration) {
                                    'MONTHLY' => 'Aylık',
                                    'YEARLY' => 'Yıllık',
                                    default => 'Belirtilmemiş',
                                },
                                $record->claimed_amount_minor !== null
                                    ? number_format($record->claimed_amount_minor / 100, 2, ',', '.').' ₺'
                                    : '—',
                                $record->customer_note ? "\nMüşteri notu: {$record->customer_note}" : '',
                            )),
                        Select::make('approved_plan_id')
                            ->label('Onaylanacak Paket')
                            ->helperText('Müşterinin talebiyle aynı olmak zorunda değil — gönderilen tutar farklı bir pakete karşılık geliyorsa burada düzeltin.')
                            ->options(fn () => Plan::query()->where('is_active', true)->pluck('name', 'id'))
                            ->default($record->plan_id)
                            ->required()
                            ->native(false),
                        Select::make('duration')
                            ->label('Aktivasyon Süresi')
                            ->helperText('Müşterinin beyan ettiği tutarla eşleşen süreyi seçin.')
                            ->options(['MONTHLY' => '1 Ay', 'YEARLY' => '1 Yıl'])
                            ->default($record->requested_duration)
                            ->required()
                            ->native(false),
                        Textarea::make('note')
                            ->label('Not (opsiyonel)'),
                    ])
                    ->action(function (PaymentRequest $record, array $data): void {
                        /** @var AdminUser $admin */
                        $admin = auth('admin')->user();
                        $record->approve($data['duration'], $admin, $data['note'] ?? null, $data['approved_plan_id']);

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
