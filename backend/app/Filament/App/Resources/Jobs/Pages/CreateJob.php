<?php

namespace App\Filament\App\Resources\Jobs\Pages;

use App\Filament\App\Resources\Jobs\JobResource;
use App\Models\Job;
use Filament\Resources\Pages\CreateRecord;

class CreateJob extends CreateRecord
{
    protected static string $resource = JobResource::class;

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        $data['code'] = 'IS-'.str_pad((string) (Job::withTrashed()->count() + 1), 4, '0', STR_PAD_LEFT);

        return $data;
    }
}
