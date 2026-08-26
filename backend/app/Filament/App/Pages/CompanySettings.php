<?php

namespace App\Filament\App\Pages;

use App\Models\Company;
use BackedEnum;
use Filament\Facades\Filament;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;

class CompanySettings extends Page implements HasForms
{
    use InteractsWithForms;

    protected string $view = 'filament.app.pages.company-settings';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedBuildingOffice2;

    protected static ?string $navigationLabel = 'Şirket Ayarları';

    protected static ?string $title = 'Şirket Ayarları';

    protected static ?int $navigationSort = 11;

    /** @var array<string, mixed>|null */
    public ?array $data = [];

    public static function canAccess(): bool
    {
        return in_array(Filament::auth()->user()?->role, ['OWNER', 'ADMIN'], true);
    }

    public function mount(): void
    {
        $this->form->fill($this->getCompany()->only(['name', 'iban', 'business_types', 'logo_path']));
    }

    public function getCompany(): Company
    {
        return Filament::auth()->user()->company;
    }

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Şirket Bilgileri')
                    ->description('Bu bilgiler tekliflerinizde, proformalarınızda ve faturalarınızda kullanılır.')
                    ->columns(2)
                    ->components([
                        FileUpload::make('logo_path')
                            ->label('Şirket Logosu')
                            ->image()
                            ->disk('public')
                            ->directory('company-logos')
                            ->imageEditor()
                            ->maxSize(4096)
                            ->columnSpanFull(),
                        TextInput::make('name')
                            ->label('Şirket Adı')
                            ->required()
                            ->maxLength(255)
                            ->columnSpanFull(),
                        TextInput::make('iban')
                            ->label('IBAN')
                            ->maxLength(255),
                        Textarea::make('business_types')
                            ->label('İşletme Türleri')
                            ->helperText('Örn. Klima Montaj/Servis, Beyaz Eşya Servisi')
                            ->default('')
                            ->dehydrateStateUsing(fn (?string $state) => $state ?? '')
                            ->columnSpanFull(),
                    ]),
            ])
            ->statePath('data');
    }

    public function save(): void
    {
        $data = $this->form->getState();

        $this->getCompany()->update($data);

        Notification::make()
            ->title('Şirket bilgileri güncellendi')
            ->success()
            ->send();
    }
}
