<?php

declare(strict_types=1);

namespace App\Filament\Pages;

use App\Models\Setting;
use App\Support\PaymentConfig;
use BackedEnum;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;

/**
 * Kart ödemesi ayarları.
 *
 * Anahtarlar girilip "Kart ödemesi etkin" açılana kadar sistem HAVALE
 * kipinde kalır: mobil ekran IBAN'ı ve elle bildirim formunu gösterir,
 * abonelik admin onayıyla uzar. Anahtarlar girildiği anda aynı ekran
 * kartla ödeme akışına geçer — uygulamada bir güncelleme gerekmez.
 *
 * Anahtarlar veritabanında ŞİFRELİ saklanır ve forma geri BASILMAZ;
 * yalnızca kayıtlı olup olmadıkları görünür. Merchant key/salt ile bir
 * saldırgan sizin adınıza ödeme isteği imzalayabilir.
 */
class PaymentSettings extends Page implements HasForms
{
    use InteractsWithForms;

    protected string $view = 'filament.pages.payment-settings';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedCreditCard;

    protected static ?string $navigationLabel = 'Ödeme ayarları';

    protected static ?string $title = 'Ödeme Ayarları';

    protected static string|\UnitEnum|null $navigationGroup = 'Sistem';

    protected static ?int $navigationSort = 3;

    /** @var array<string, mixed>|null */
    public ?array $data = [];

    public function mount(): void
    {
        $this->form->fill([
            'provider' => PaymentConfig::provider(),
            'enabled' => PaymentConfig::isEnabled(),
            'test_mode' => PaymentConfig::isTestMode(),
            // Anahtarların kendisi DOLDURULMAZ; boş bırakılırsa mevcut
            // değer korunur.
            'merchant_id' => null,
            'merchant_key' => null,
            'merchant_salt' => null,
        ]);
    }

    public function form(Schema $schema): Schema
    {
        $kayitli = static function (string $key): string {
            $maskeli = PaymentConfig::maskedSecret($key);

            return $maskeli === null
                ? 'Kayıtlı değil.'
                : 'Kayıtlı: '.$maskeli.' — değiştirmek istemiyorsanız boş bırakın.';
        };

        return $schema
            ->components([
                Section::make('Durum')
                    ->description(
                        'Kart ödemesi kapalıyken kullanıcılar IBAN\'a havale '
                        .'yapıp uygulamadan bildirim gönderir ve aboneliği '
                        .'siz onaylarsınız. Açtığınızda aynı ekran kartla '
                        .'ödemeye geçer; uygulama güncellemesi gerekmez.'
                    )
                    ->components([
                        Select::make('provider')
                            ->label('Sağlayıcı')
                            ->options([
                                PaymentConfig::PROVIDER_NONE => 'Yok (havale)',
                                PaymentConfig::PROVIDER_PAYTR => 'PayTR',
                            ])
                            ->native(false)
                            ->required(),

                        Toggle::make('enabled')
                            ->label('Kart ödemesi etkin')
                            ->helperText(
                                'Anahtarlardan biri eksikse bu açık olsa '
                                .'bile sistem havale kipinde kalır — '
                                .'kullanıcıyı çalışmayan bir ödeme ekranına '
                                .'göndermemek için.'
                            ),

                        Toggle::make('test_mode')
                            ->label('Test kipi')
                            ->helperText(
                                'Açıkken sağlayıcının test ortamı kullanılır; '
                                .'gerçek para çekilmez.'
                            ),
                    ])
                    ->columns(3),

                Section::make('PayTR anahtarları')
                    ->description(
                        'PayTR mağaza panelinden alınır. Buraya girilen '
                        .'değerler şifreli saklanır ve bir daha ekranda '
                        .'gösterilmez.'
                    )
                    ->components([
                        TextInput::make('merchant_id')
                            ->label('Merchant ID')
                            ->password()
                            ->revealable()
                            ->autocomplete(false)
                            ->helperText($kayitli('payment.paytr.merchant_id')),

                        TextInput::make('merchant_key')
                            ->label('Merchant Key')
                            ->password()
                            ->revealable()
                            ->autocomplete(false)
                            ->helperText($kayitli('payment.paytr.merchant_key')),

                        TextInput::make('merchant_salt')
                            ->label('Merchant Salt')
                            ->password()
                            ->revealable()
                            ->autocomplete(false)
                            ->helperText($kayitli('payment.paytr.merchant_salt')),
                    ]),
            ])
            ->statePath('data');
    }

    public function save(): void
    {
        $data = $this->form->getState();

        Setting::set(
            PaymentConfig::KEY_PROVIDER,
            (string) ($data['provider'] ?? PaymentConfig::PROVIDER_NONE),
        );
        Setting::set(
            PaymentConfig::KEY_ENABLED,
            ($data['enabled'] ?? false) ? '1' : '0',
        );
        Setting::set(
            PaymentConfig::KEY_TEST_MODE,
            ($data['test_mode'] ?? true) ? '1' : '0',
        );

        // Boş bırakılan anahtar SİLİNMEZ; mevcut değer korunur. Aksi halde
        // yalnızca test kipini değiştirmek isteyen biri, farkında olmadan
        // tüm anahtarları siler ve ödeme durur.
        foreach ([
            'merchant_id' => 'payment.paytr.merchant_id',
            'merchant_key' => 'payment.paytr.merchant_key',
            'merchant_salt' => 'payment.paytr.merchant_salt',
        ] as $alan => $anahtar) {
            $deger = $data[$alan] ?? null;
            if ($deger !== null && trim((string) $deger) !== '') {
                PaymentConfig::setSecret($anahtar, (string) $deger);
            }
        }

        $kip = PaymentConfig::mode();

        Notification::make()
            ->title('Ödeme ayarları kaydedildi')
            ->body($kip === PaymentConfig::MODE_CARD
                ? 'Kart ödemesi devrede. Uygulamalar bir sonraki açılışta kart akışını gösterecek.'
                : 'Sistem havale kipinde. Kart akışının açılması için sağlayıcı, anahtarlar ve "etkin" işareti birlikte gerekiyor.')
            ->success()
            ->send();

        // Anahtarlar forma geri basılmaz.
        $this->form->fill([
            'provider' => PaymentConfig::provider(),
            'enabled' => PaymentConfig::isEnabled(),
            'test_mode' => PaymentConfig::isTestMode(),
            'merchant_id' => null,
            'merchant_key' => null,
            'merchant_salt' => null,
        ]);
    }
}
