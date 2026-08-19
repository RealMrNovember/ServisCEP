<?php

namespace App\Filament\App\Resources\IncomeEntries\Pages;

use App\Filament\App\Resources\IncomeEntries\IncomeEntryResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

class EditIncomeEntry extends EditRecord
{
    protected static string $resource = IncomeEntryResource::class;

    protected function getHeaderActions(): array
    {
        return [
            DeleteAction::make(),
        ];
    }
}
