<?php

namespace App\Filament\App\Resources\IncomeEntries\Pages;

use App\Filament\App\Resources\IncomeEntries\IncomeEntryResource;
use Filament\Resources\Pages\CreateRecord;

class CreateIncomeEntry extends CreateRecord
{
    protected static string $resource = IncomeEntryResource::class;
}
