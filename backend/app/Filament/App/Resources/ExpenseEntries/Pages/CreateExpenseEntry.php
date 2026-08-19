<?php

namespace App\Filament\App\Resources\ExpenseEntries\Pages;

use App\Filament\App\Resources\ExpenseEntries\ExpenseEntryResource;
use Filament\Resources\Pages\CreateRecord;

class CreateExpenseEntry extends CreateRecord
{
    protected static string $resource = ExpenseEntryResource::class;
}
