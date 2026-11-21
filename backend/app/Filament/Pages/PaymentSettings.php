<?php

declare(strict_types=1);

namespace App\Filament\Pages;

use App\Http\Controllers\Api\V1\SubscriptionController;
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
            'secret_key' => null,
            'webhook_secret' => null,
            'support_whatsapp' => Setting::get(
                SubscriptionController::KEY_SUPPORT_WHATSAPP,
                SubscriptionController::VARSAYILAN_WHATSAPP,
            ),
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
                                PaymentConfig::PROVIDER_STRIPE => 'Stripe',
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

                Section::make('Stripe anahtarları')
                    ->description(
                        'Stripe Dashboard\'dan alınır: restricted bir '
                        .'anahtar (Checkout Sessions: Write) ve webhook '
                        .'uç noktasının imza sırrı (whsec_...). Buraya '
                        .'girilen değerler şifreli saklanır ve bir daha '
                        .'ekranda gösterilmez.'
                    )
                    ->components([
                        TextInput::make('secret_key')
                            ->label('Secret key (rk_... / sk_...)')
                            ->password()
                            ->revealable()
                            ->autocomplete(false)
                            ->helperText($kayitli('payment.stripe.secret_key')),

                        TextInput::make('webhook_secret')
                            ->label('Webhook signing secret (whsec_...)')
                            ->password()
                            ->revealable()
                            ->autocomplete(false)
                            ->helperText($kayitli('payment.stripe.webhook_secret')),
                    ]),

                Section::make('Destek')
                    ->description(
                        'Aboneliği dolduğu için yeni kayıt giremeyen '
                        .'kullanıcının son çıkışı. Boş bırakılırsa '
                        .'uygulamada WhatsApp düğmesi hiç görünmez — '
                        .'çalışmayan bir düğme, olmayan düğmeden kötüdür.'
                    )
                    ->components([
                        TextInput::make('support_whatsapp')
                            ->label('Destek WhatsApp numarası')
                            ->helperText(
                                'Yalnızca rakam, ülke kodu dahil, artı '
                                .'işareti ve boşluk olmadan. Örn. '
                                .'905354895050'
                            )
                            ->rule('regex:/^[0-9]{10,15}$/')
                            ->placeholder('905354895050'),
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
            'secret_key' => 'payment.stripe.secret_key',
            'webhook_secret' => 'payment.stripe.webhook_secret',
        ] as $alan => $anahtar) {
            $deger = $data[$alan] ?? null;
            if ($deger !== null && trim((string) $deger) !== '') {
                PaymentConfig::setSecret($anahtar, (string) $deger);
            }
        }

        // Destek numarası: boş bırakılırsa ayar SİLİNİR ve koddaki
        // varsayılana dönülür — "numarayı kaldırmak" mümkün olmalı.
        $numara = trim((string) ($data['support_whatsapp'] ?? ''));
        Setting::set(SubscriptionController::KEY_SUPPORT_WHATSAPP, $numara);

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
            'secret_key' => null,
            'webhook_secret' => null,
        ]);
    }
}
