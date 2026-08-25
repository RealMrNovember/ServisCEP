<?php

declare(strict_types=1);

namespace App\Filament\Pages;

use App\Http\Controllers\Api\V1\AppVersionController;
use App\Models\Setting;
use BackedEnum;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;

/**
 * Mobil uygulamanın yayındaki sürümü.
 *
 * Uygulama, güncelleme olup olmadığını Play'e değil BURAYA sorar. Play'in
 * kendi kontrolü, sürüm o cihaza yayılana kadar sessiz kalıyor ve bu
 * saatler sürebiliyor; kullanıcı güncellemeden haberdar olmuyordu.
 * Buradan yönetince "yayında" anını biz belirliyoruz.
 *
 * Kurulum yine Play üzerinden yapılır — Android'de başka yolu yok.
 */
class AppVersionSettings extends Page implements HasForms
{
    use InteractsWithForms;

    protected string $view = 'filament.pages.app-version-settings';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedDevicePhoneMobile;

    protected static ?string $navigationLabel = 'Uygulama sürümü';

    protected static ?string $title = 'Uygulama Sürümü';

    protected static string|\UnitEnum|null $navigationGroup = 'Sistem';

    protected static ?int $navigationSort = 2;

    /** @var array<string, mixed>|null */
    public ?array $data = [];

    public function mount(): void
    {
        $this->form->fill([
            'latest_version' => Setting::get(AppVersionController::KEY_VERSION),
            'latest_build' => Setting::get(AppVersionController::KEY_BUILD),
            'min_build' => Setting::get(AppVersionController::KEY_MIN_BUILD),
            'notes' => Setting::get(AppVersionController::KEY_NOTES),
            'store_url' => Setting::get(
                AppVersionController::KEY_STORE_URL,
                AppVersionController::DEFAULT_STORE_URL,
            ),
        ]);
    }

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Yayındaki sürüm')
                    ->description(
                        'Uygulama açılışta bu bilgiyi sorar. Sürüm kodu, '
                        .'kullanıcının kurulu sürümünden büyükse güncelleme '
                        .'önerilir. Play Store’a yükleme tamamlanmadan '
                        .'burayı güncellemeyin — kullanıcı henüz '
                        .'indiremeyeceği bir güncellemeye yönlendirilir.'
                    )
                    ->components([
                        TextInput::make('latest_version')
                            ->label('Sürüm adı')
                            ->placeholder('0.7.2')
                            ->helperText('Kullanıcıya gösterilir.'),

                        TextInput::make('latest_build')
                            ->label('Sürüm kodu')
                            ->numeric()
                            ->placeholder('26')
                            ->helperText(
                                'Karşılaştırma bu sayıyla yapılır '
                                .'(pubspec.yaml’daki "+" sonrası).'
                            ),

                        TextInput::make('min_build')
                            ->label('En düşük desteklenen sürüm kodu')
                            ->numeric()
                            ->default(0)
                            ->helperText(
                                'Bu kodun altındaki kurulumlarda güncelleme '
                                .'ZORUNLU olur ve ertelenemez. Yalnızca '
                                .'sunucu sözleşmesi kırıldığında kullanın; '
                                .'aksi halde 0 bırakın.'
                            ),

                        TextInput::make('store_url')
                            ->label('Mağaza bağlantısı')
                            ->url()
                            ->helperText('Güncelle düğmesi buraya gider.')
                            ->columnSpanFull(),

                        Textarea::make('notes')
                            ->label('Sürüm notu')
                            ->rows(5)
                            ->helperText(
                                'Güncelleme penceresinde gösterilir. '
                                .'CHANGELOG.md’deki metni buraya '
                                .'kopyalayabilirsiniz.'
                            )
                            ->columnSpanFull(),
                    ]),
            ])
            ->statePath('data');
    }

    public function save(): void
    {
        $data = $this->form->getState();

        // `numeric()` alanlar formdan sayı olarak geliyor; ayar deposu
        // metin saklıyor.
        $metin = static fn ($value): ?string => $value === null || $value === ''
            ? null
            : (string) $value;

        Setting::set(AppVersionController::KEY_VERSION, $metin($data['latest_version'] ?? null));
        Setting::set(AppVersionController::KEY_BUILD, $metin($data['latest_build'] ?? null));
        Setting::set(AppVersionController::KEY_MIN_BUILD, $metin($data['min_build'] ?? null) ?? '0');
        Setting::set(AppVersionController::KEY_NOTES, $metin($data['notes'] ?? null));
        Setting::set(AppVersionController::KEY_STORE_URL, $metin($data['store_url'] ?? null));

        Notification::make()
            ->title('Sürüm bilgisi kaydedildi')
            ->body('Uygulamalar bir sonraki açılışta bu bilgiyi görecek.')
            ->success()
            ->send();
    }
}
