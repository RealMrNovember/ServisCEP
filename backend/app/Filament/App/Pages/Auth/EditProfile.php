<?php

namespace App\Filament\App\Pages\Auth;

use Filament\Auth\Pages\EditProfile as BaseEditProfile;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\TextInput;
use Filament\Schemas\Components\Component;
use Filament\Schemas\Schema;

class EditProfile extends BaseEditProfile
{
    protected function getNameFormComponent(): Component
    {
        return TextInput::make('full_name')
            ->label('Ad Soyad')
            ->required()
            ->maxLength(255)
            ->autofocus();
    }

    protected function getAvatarFormComponent(): Component
    {
        return FileUpload::make('avatar_path')
            ->label('Profil Fotoğrafı')
            ->avatar()
            ->disk('public')
            ->directory('avatars');
    }

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                $this->getAvatarFormComponent(),
                $this->getNameFormComponent(),
                $this->getEmailFormComponent(),
                $this->getPasswordFormComponent(),
                $this->getPasswordConfirmationFormComponent(),
                $this->getCurrentPasswordFormComponent(),
            ]);
    }
}
