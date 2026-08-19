<?php

namespace App\Filament\Pages;

use App\Models\Setting;
use BackedEnum;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;

/**
 * Havale/EFT ile manuel ödeme kabulü için banka bilgileri — bkz. docs/13.
 * Kasıtlı olarak koda/seed'e yazılmaz, yalnızca burada (veritabanında)
 * tutulur; admin panelden girilir.
 */
class PaymentSettings extends Page implements HasForms
{
    use InteractsWithForms;

    protected string $view = 'filament.pages.payment-settings';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedCreditCard;

    protected static ?string $navigationLabel = 'Ödeme Ayarları';

    protected static ?string $title = 'Ödeme Ayarları';

    protected static ?int $navigationSort = 4;

    /** @var array<string, mixed>|null */
    public ?array $data = [];

    public function mount(): void
    {
        $this->form->fill([
            'iban' => Setting::get('payment_iban'),
            'account_holder' => Setting::get('payment_account_holder'),
            'bank_name' => Setting::get('payment_bank_name'),
            'note' => Setting::get('payment_note'),
        ]);
    }

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Havale/EFT Bilgileri')
                    ->description('Müşterilerinize ödeme talebi ekranında gösterilecek banka bilgileri. Şu an tek ödeme yöntemi budur — otomatik online ödeme entegrasyonu henüz yok.')
                    ->components([
                        TextInput::make('iban')
                            ->label('IBAN')
                            ->placeholder('TR__ ____ ____ ____ ____ ____ __'),
                        TextInput::make('account_holder')
                            ->label('Hesap Sahibi'),
                        TextInput::make('bank_name')
                            ->label('Banka Adı'),
                        Textarea::make('note')
                            ->label('Fiyatlandırma / ödeme notu')
                            ->helperText('Hizmet bedeli henüz kesinleşmediyse burada geçici olarak açıklayabilirsiniz — müşteri panelinde bu not gösterilir.')
                            ->columnSpanFull(),
                    ]),
            ])
            ->statePath('data');
    }

    public function save(): void
    {
        $data = $this->form->getState();

        Setting::set('payment_iban', $data['iban'] ?? null);
        Setting::set('payment_account_holder', $data['account_holder'] ?? null);
        Setting::set('payment_bank_name', $data['bank_name'] ?? null);
        Setting::set('payment_note', $data['note'] ?? null);

        Notification::make()
            ->title('Ödeme ayarları kaydedildi')
            ->success()
            ->send();
    }
}
