<?php

declare(strict_types=1);

namespace App\Filament\Resources\SubscriptionPayments;

use App\Models\SubscriptionPayment;
use Filament\Actions\Action;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Support\HtmlString;

class SubscriptionPaymentsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn ($query) => $query->with(['company', 'plan']))
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('created_at')
                    ->label('Tarih')
                    ->dateTime('d.m.Y H:i')
                    ->sortable(),

                TextColumn::make('company.name')
                    ->label('Şirket')
                    ->weight(FontWeight::SemiBold)
                    ->searchable()
                    ->sortable(),

                TextColumn::make('plan.name')
                    ->label('Paket')
                    ->placeholder('—'),

                TextColumn::make('duration')
                    ->label('Süre')
                    ->badge()
                    ->formatStateUsing(fn (?string $state) => $state === SubscriptionPayment::DURATION_YEARLY
                        ? 'Yıllık'
                        : 'Aylık')
                    ->color('gray'),

                TextColumn::make('amount_minor')
                    ->label('Tutar')
                    ->alignEnd()
                    ->formatStateUsing(fn (int $state) => number_format($state / 100, 2, ',', '.').' ₺')
                    ->sortable(),

                TextColumn::make('status')
                    ->label('Durum')
                    ->badge()
                    ->formatStateUsing(fn (?string $state) => match ($state) {
                        SubscriptionPayment::STATUS_PAID => 'Ödendi',
                        SubscriptionPayment::STATUS_FAILED => 'Başarısız',
                        default => 'Bekliyor',
                    })
                    ->color(fn (?string $state) => match ($state) {
                        SubscriptionPayment::STATUS_PAID => 'success',
                        SubscriptionPayment::STATUS_FAILED => 'danger',
                        default => 'warning',
                    }),

                TextColumn::make('provider_ref')
                    ->label('Sipariş No')
                    ->copyable()
                    ->copyMessage('Sipariş no kopyalandı')
                    ->searchable()
                    ->toggleable()
                    ->fontFamily('mono'),

                TextColumn::make('paid_at')
                    ->label('Ödeme anı')
                    ->dateTime('d.m.Y H:i')
                    ->placeholder('—')
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                SelectFilter::make('status')
                    ->label('Durum')
                    ->options([
                        SubscriptionPayment::STATUS_PAID => 'Ödendi',
                        SubscriptionPayment::STATUS_PENDING => 'Bekliyor',
                        SubscriptionPayment::STATUS_FAILED => 'Başarısız',
                    ]),
                SelectFilter::make('company_id')
                    ->label('Şirket')
                    ->relationship('company', 'name')
                    ->searchable()
                    ->preload(),
            ])
            ->recordActions([
                // Sağlayıcıdan gelen ham bildirim. Bir anlaşmazlıkta ya da
                // "para çekildi mi" sorusunda tek kanıt bu.
                Action::make('payload')
                    ->label('Sağlayıcı Yanıtı')
                    ->icon('heroicon-o-code-bracket')
                    ->modalHeading(fn (SubscriptionPayment $record) => 'Sipariş '.$record->provider_ref)
                    ->modalSubmitAction(false)
                    ->modalCancelActionLabel('Kapat')
                    ->visible(fn (SubscriptionPayment $record) => $record->provider_payload !== null)
                    ->modalContent(fn (SubscriptionPayment $record) => new HtmlString(
                        '<pre style="white-space:pre-wrap;word-break:break-all;'
                        .'font-size:12px;line-height:1.6;padding:12px;'
                        .'border-radius:8px;background:#0b0c0f;color:#e5e7eb;">'
                        .e(json_encode(
                            $record->provider_payload,
                            JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
                        ) ?: '')
                        .'</pre>'
                    )),
            ]);
    }
}
