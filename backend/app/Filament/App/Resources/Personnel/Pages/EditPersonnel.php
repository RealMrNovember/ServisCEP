<?php

namespace App\Filament\App\Resources\Personnel\Pages;

use App\Filament\App\Resources\Personnel\PersonnelResource;
use Filament\Actions\DeleteAction;
use Filament\Facades\Filament;
use Filament\Resources\Pages\EditRecord;

class EditPersonnel extends EditRecord
{
    protected static string $resource = PersonnelResource::class;

    protected function getHeaderActions(): array
    {
        return [
            DeleteAction::make()
                ->visible(fn () => $this->record->id !== Filament::auth()->id()),
        ];
    }
}
