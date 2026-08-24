<?php

declare(strict_types=1);

namespace App\Filament\Resources\Users\Pages;

use App\Filament\Resources\Users\UserResource;
use Filament\Resources\Pages\ListRecords;

class ListUsers extends ListRecords
{
    protected static string $resource = UserResource::class;

    // Kasıtlı olarak "Yeni" aksiyonu yok — bkz. UserResource sınıf notu.
    protected function getHeaderActions(): array
    {
        return [];
    }
}
