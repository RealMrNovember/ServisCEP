<?php

declare(strict_types=1);

namespace App\Filament\Resources\SubscriptionPayments\Pages;

use App\Filament\Resources\SubscriptionPayments\SubscriptionPaymentResource;
use Filament\Resources\Pages\ListRecords;

class ListSubscriptionPayments extends ListRecords
{
    protected static string $resource = SubscriptionPaymentResource::class;
}
