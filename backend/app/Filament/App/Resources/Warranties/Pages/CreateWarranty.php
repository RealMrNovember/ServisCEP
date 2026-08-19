<?php

namespace App\Filament\App\Resources\Warranties\Pages;

use App\Filament\App\Resources\Warranties\WarrantyResource;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Support\Carbon;

class CreateWarranty extends CreateRecord
{
    protected static string $resource = WarrantyResource::class;

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        $data['warranty_expires_at'] = Carbon::parse($data['install_date'])
            ->addMonths((int) $data['warranty_months']);

        return $data;
    }
}
