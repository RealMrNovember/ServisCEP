<?php

namespace App\Filament\App\Resources\Warranties\Pages;

use App\Filament\App\Resources\Warranties\WarrantyResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;
use Illuminate\Support\Carbon;

class EditWarranty extends EditRecord
{
    protected static string $resource = WarrantyResource::class;

    protected function getHeaderActions(): array
    {
        return [
            DeleteAction::make(),
        ];
    }

    protected function mutateFormDataBeforeSave(array $data): array
    {
        $data['warranty_expires_at'] = Carbon::parse($data['install_date'])
            ->addMonths((int) $data['warranty_months']);

        return $data;
    }
}
