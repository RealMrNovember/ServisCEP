<?php

namespace App\Filament\App\Pages\Auth;

use App\Models\Company;
use App\Models\User;
use Filament\Auth\Pages\Register;
use Filament\Forms\Components\TextInput;
use Filament\Schemas\Components\Component;
use Filament\Schemas\Schema;
use Illuminate\Database\Eloquent\Model;
use SensitiveParameter;

/**
 * Yeni şirket kaydı — Filament'in varsayılan tek-modelli Register sayfası
 * yerine, aynı formda hem Company hem de sahibi olan User (OWNER) oluşturur.
 */
class RegisterCompany extends Register
{
    protected function getCompanyNameFormComponent(): Component
    {
        return TextInput::make('company_name')
            ->label('Şirket Adı')
            ->required()
            ->maxLength(255)
            ->autofocus();
    }

    protected function getNameFormComponent(): Component
    {
        return TextInput::make('full_name')
            ->label('Ad Soyad')
            ->required()
            ->maxLength(255);
    }

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                $this->getCompanyNameFormComponent(),
                $this->getNameFormComponent(),
                $this->getEmailFormComponent(),
                $this->getPasswordFormComponent(),
                $this->getPasswordConfirmationFormComponent(),
            ]);
    }

    protected function handleRegistration(#[SensitiveParameter] array $data): Model
    {
        $company = Company::create([
            'name' => $data['company_name'],
        ]);

        return User::create([
            'company_id' => $company->id,
            'full_name' => $data['full_name'],
            'email' => $data['email'],
            'password' => $data['password'],
        ]);
    }
}
