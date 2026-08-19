<?php

namespace App\Filament\Resources\PaymentRequests;

use App\Filament\Resources\PaymentRequests\Pages\EditPaymentRequest;
use App\Filament\Resources\PaymentRequests\Pages\ListPaymentRequests;
use App\Filament\Resources\PaymentRequests\Schemas\PaymentRequestForm;
use App\Filament\Resources\PaymentRequests\Tables\PaymentRequestsTable;
use App\Models\PaymentRequest;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;

class PaymentRequestResource extends Resource
{
    protected static ?string $model = PaymentRequest::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedBanknotes;

    protected static ?string $modelLabel = 'Ödeme Talebi';

    protected static ?string $pluralModelLabel = 'Ödeme Talepleri';

    protected static ?string $navigationLabel = 'Ödeme Talepleri';

    protected static ?int $navigationSort = 3;

    public static function form(Schema $schema): Schema
    {
        return PaymentRequestForm::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return PaymentRequestsTable::configure($table);
    }

    public static function getRelations(): array
    {
        return [
            //
        ];
    }

    public static function getNavigationBadge(): ?string
    {
        $count = static::getModel()::query()->where('status', 'PENDING')->count();

        return $count > 0 ? (string) $count : null;
    }

    public static function getNavigationBadgeColor(): ?string
    {
        return 'warning';
    }

    public static function getPages(): array
    {
        return [
            'index' => ListPaymentRequests::route('/'),
            'edit' => EditPaymentRequest::route('/{record}/edit'),
        ];
    }
}
