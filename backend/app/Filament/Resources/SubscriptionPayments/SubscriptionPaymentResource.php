<?php

declare(strict_types=1);

namespace App\Filament\Resources\SubscriptionPayments;

use App\Filament\Resources\SubscriptionPayments\Pages\ListSubscriptionPayments;
use App\Models\SubscriptionPayment;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;

/**
 * Kartla yapılan abonelik ödemeleri.
 *
 * Salt okunur: bu kayıtlar sağlayıcının bildirimiyle oluşur, elle
 * düzenlenmemeli. Bir ödemede sorun varsa çözüm sağlayıcı panelinde ya da
 * "Süre Uzat" aksiyonundadır — buradaki kaydı değiştirmek gerçeği
 * değiştirmez, yalnızca izi bozar.
 */
class SubscriptionPaymentResource extends Resource
{
    protected static ?string $model = SubscriptionPayment::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedCreditCard;

    protected static ?string $navigationLabel = 'Kart Ödemeleri';

    protected static ?string $modelLabel = 'Kart ödemesi';

    protected static ?string $pluralModelLabel = 'Kart Ödemeleri';

    protected static string|\UnitEnum|null $navigationGroup = 'Abonelik';

    protected static ?int $navigationSort = 3;

    public static function table(Table $table): Table
    {
        return SubscriptionPaymentsTable::configure($table);
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function getPages(): array
    {
        return [
            'index' => ListSubscriptionPayments::route('/'),
        ];
    }

    /** Bekleyen ödeme varsa rozet çıkar — takılan işlem görünür olsun. */
    public static function getNavigationBadge(): ?string
    {
        $bekleyen = SubscriptionPayment::where('status', SubscriptionPayment::STATUS_PENDING)->count();

        return $bekleyen > 0 ? (string) $bekleyen : null;
    }

    public static function getNavigationBadgeColor(): ?string
    {
        return 'warning';
    }
}
