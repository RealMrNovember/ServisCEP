<?php

namespace App\Filament\App\Resources\ExpenseEntries\Pages;

use App\Filament\App\Resources\ExpenseEntries\ExpenseEntryResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListExpenseEntries extends ListRecords
{
    protected static string $resource = ExpenseEntryResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make(),
        ];
    }
}
