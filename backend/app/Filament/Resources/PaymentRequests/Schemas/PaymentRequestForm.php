<?php

namespace App\Filament\Resources\PaymentRequests\Schemas;

use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Textarea;
use Filament\Schemas\Schema;

class PaymentRequestForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Select::make('company_id')
                    ->label('Şirket')
                    ->relationship('company', 'name')
                    ->required()
                    ->disabled(),
                Select::make('plan_id')
                    ->label('Talep edilen paket')
                    ->relationship('plan', 'name')
                    ->disabled(),
                Select::make('approved_plan_id')
                    ->label('Onaylanan paket')
                    ->relationship('approvedPlan', 'name')
                    ->disabled(),
                TextInput::make('requested_duration')
                    ->label('Talep edilen süre')
                    ->disabled(),
                TextInput::make('claimed_amount_minor')
                    ->label('Beyan edilen tutar (kuruş)')
                    ->numeric()
                    ->disabled(),
                Textarea::make('customer_note')
                    ->label('Müşteri notu')
                    ->disabled()
                    ->columnSpanFull(),
                TextInput::make('status')
                    ->label('Durum')
                    ->disabled(),
                Textarea::make('admin_note')
                    ->label('Admin notu')
                    ->columnSpanFull(),
            ]);
    }
}
