<?php

namespace App\Filament\App\Resources\Customers\Pages;

use App\Filament\App\Resources\Customers\CustomerResource;
use App\Models\Customer;
use Filament\Resources\Pages\CreateRecord;

class CreateCustomer extends CreateRecord
{
    protected static string $resource = CustomerResource::class;

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        $data['code'] = 'MUS-'.str_pad((string) (Customer::withTrashed()->count() + 1), 4, '0', STR_PAD_LEFT);

        return $data;
    }
}
