<?php

namespace App\Filament\App\Resources\IncomeEntries\Pages;

use App\Filament\App\Resources\IncomeEntries\IncomeEntryResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListIncomeEntries extends ListRecords
{
    protected static string $resource = IncomeEntryResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make(),
        ];
    }
}
