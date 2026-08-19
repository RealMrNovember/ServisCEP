<?php

namespace App\Filament\App\Resources\Proformas\Pages;

use App\Filament\App\Resources\Proformas\ProformaResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListProformas extends ListRecords
{
    protected static string $resource = ProformaResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make(),
        ];
    }
}
