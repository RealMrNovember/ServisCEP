<?php

namespace App\Filament\App\Resources\Personnel\Pages;

use App\Filament\App\Resources\Personnel\PersonnelResource;
use Filament\Facades\Filament;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\CreateRecord;
use Filament\Support\Exceptions\Halt;

class CreatePersonnel extends CreateRecord
{
    protected static string $resource = PersonnelResource::class;

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        $company = Filament::auth()->user()->company;
        $maxUsers = $company->plan?->max_users;

        if ($maxUsers !== null && $company->users()->count() >= $maxUsers) {
            Notification::make()
                ->title('Kullanıcı limitine ulaşıldı')
                ->body("Mevcut paketiniz (\"{$company->plan->name}\") en fazla {$maxUsers} kullanıcıya izin veriyor. Daha fazla personel eklemek için paketinizi yükseltin.")
                ->danger()
                ->send();

            throw new Halt;
        }

        $data['company_id'] = $company->id;

        return $data;
    }
}
