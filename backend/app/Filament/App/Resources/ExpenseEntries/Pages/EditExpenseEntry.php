<?php

namespace App\Filament\App\Resources\ExpenseEntries\Pages;

use App\Filament\App\Resources\ExpenseEntries\ExpenseEntryResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

class EditExpenseEntry extends EditRecord
{
    protected static string $resource = ExpenseEntryResource::class;

    protected function getHeaderActions(): array
    {
        return [
            DeleteAction::make(),
        ];
    }
}
