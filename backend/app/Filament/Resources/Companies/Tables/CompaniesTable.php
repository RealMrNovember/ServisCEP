<?php

namespace App\Filament\Resources\Companies\Tables;

use App\Http\Controllers\Api\V1\AppVersionController;
use App\Models\Company;
use App\Models\Plan;
use App\Services\SubscriptionService;
use Filament\Actions\Action;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\DatePicker;
use Filament\Forms\Components\Radio;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Placeholder;
use Filament\Notifications\Notification;
use Filament\Schemas\Components\Utilities\Get;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\HtmlString;

class CompaniesTable
{
    /** Abonelik modalının başındaki "şu an ne durumdayız" özeti. */
    private static function currentStatusHtml(Company $record): string
    {
        $expires = $record->subscription_expires_at;
        $remaining = $expires !== null
            ? (int) ceil(Carbon::now()->diffInDays($expires, false))
            : null;

        $state = match (true) {
            $expires === null => '<span class="text-gray-500">Süresiz</span>',
            $remaining < 0 => sprintf(
                '<span class="font-semibold text-danger-600">%s — %d gün önce doldu</span>',
                e($expires->translatedFormat('d F Y')),
                abs($remaining),
            ),
            default => sprintf(
                '<span class="font-semibold">%s — %d gün kaldı</span>',
                e($expires->translatedFormat('d F Y')),
                $remaining,
            ),
        };

        return sprintf(
            '%s<br><span class="text-sm text-gray-500">Paket: %s · Kullanıcı: %d</span>',
            $state,
            e($record->plan?->name ?? 'Yok'),
            $record->users()->count(),
        );
    }

    private static function ownerOf(Company $record): ?object
    {
        return $record->users->firstWhere('role', 'OWNER') ?? $record->users->first();
    }

    public static function configure(Table $table): Table
    {
        return $table
            // 'users' eager-load: yetkili adı/e-postası her satırda okunuyor,
            // aksi halde liste N+1 sorgu üretirdi.
            ->modifyQueryUsing(fn ($query) => $query->with(['users', 'plan']))
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('name')
                    ->label('Şirket')
                    ->weight(FontWeight::SemiBold)
                    ->searchable(),
                // Şirket adı tek başına kimin olduğunu söylemiyordu; destek
                // için her seferinde kaydın içine girmek gerekiyordu.
                TextColumn::make('owner_name')
                    ->label('Yetkili')
                    ->getStateUsing(fn (Company $record) => self::ownerOf($record)?->full_name)
                    ->placeholder('—')
                    ->searchable(query: fn ($query, string $search) => $query->whereHas(
                        'users',
                        fn ($q) => $q->where('full_name', 'like', "%{$search}%")
                    )),
                TextColumn::make('owner_email')
                    ->label('E-posta')
                    ->getStateUsing(fn (Company $record) => self::ownerOf($record)?->email)
                    ->placeholder('—')
                    ->copyable()
                    ->copyMessage('E-posta kopyalandı')
                    ->searchable(query: fn ($query, string $search) => $query->whereHas(
                        'users',
                        fn ($q) => $q->where('email', 'like', "%{$search}%")
                    )),
                TextColumn::make('owner_phone')
                    ->label('Telefon')
                    ->getStateUsing(fn (Company $record) => self::ownerOf($record)?->phone)
                    ->placeholder('—')
                    ->copyable()
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('plan.name')
                    ->label('Paket')
                    ->badge()
                    ->searchable(),
                TextColumn::make('subscription_expires_at')
                    ->label('Abonelik Bitişi')
                    ->dateTime('d.m.Y H:i')
                    ->placeholder('Süresiz')
                    ->color(fn (?Carbon $state) => $state === null ? 'gray' : ($state->isPast() ? 'danger' : ($state->diffInDays(now()) <= 3 ? 'warning' : 'success')))
                    ->sortable(),
                IconColumn::make('is_active')
                    ->label('Aktif')
                    ->boolean(),
                TextColumn::make('users_count')
                    ->label('Kullanıcı')
                    ->counts('users'),
                // Şirketteki en düşük sürüm. Bir şirket sorun bildirdiğinde
                // "hepsi güncel mi, yoksa biri geride mi kalmış" sorusunun
                // tek bakışta cevabı. En düşüğü göstermek bilinçli: bir kişi
                // bile eskideyse şirket için risk var demektir.
                TextColumn::make('en_dusuk_surum')
                    ->label('En eski sürüm')
                    ->badge()
                    ->placeholder('bilinmiyor')
                    ->state(function (Company $record): ?string {
                        $kullanicilar = $record->users()
                            ->whereNotNull('app_build')
                            ->orderBy('app_build')
                            ->get(['app_version', 'app_build']);

                        if ($kullanicilar->isEmpty()) {
                            return null;
                        }

                        $enDusuk = $kullanicilar->first();
                        $geride = $kullanicilar
                            ->where('app_build', '<', AppVersionController::currentBuild())
                            ->count();

                        return $geride > 0
                            ? $enDusuk->app_version.' ('.$geride.' kişi geride)'
                            : $enDusuk->app_version;
                    })
                    ->color(fn (?string $state) => match (true) {
                        $state === null => 'gray',
                        str_contains($state, 'geride') => 'warning',
                        default => 'success',
                    }),
                TextColumn::make('created_at')
                    ->label('Kayıt Tarihi')
                    ->dateTime('d.m.Y')
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                TernaryFilter::make('is_active')->label('Aktif mi'),
            ])
            ->recordActions([
                Action::make('extend')
                    ->label('Aboneliği Yönet')
                    ->icon('heroicon-o-clock')
                    ->color('success')
                    ->modalHeading(fn (Company $record) => 'Abonelik — '.$record->name)
                    ->modalSubmitActionLabel('Uygula')
                    ->schema(fn (Company $record) => [
                        Placeholder::make('current')
                            ->label('Mevcut durum')
                            ->content(fn () => new HtmlString(self::currentStatusHtml($record))),

                        Radio::make('mode')
                            ->label('Ne yapmak istiyorsun?')
                            ->options([
                                'add' => 'Süre ekle',
                                'exact' => 'Bitiş tarihini doğrudan belirle',
                            ])
                            ->default('add')
                            ->live()
                            ->required(),

                        Select::make('months')
                            ->label('Eklenecek süre')
                            ->options([
                                '1' => '1 Ay',
                                '3' => '3 Ay',
                                '6' => '6 Ay',
                                '12' => '1 Yıl',
                                '0' => 'Ay ekleme (yalnızca gün)',
                            ])
                            ->default('1')
                            ->native(false)
                            ->live()
                            ->visible(fn (Get $get) => $get('mode') === 'add'),

                        TextInput::make('days')
                            ->label('Ek gün (opsiyonel)')
                            ->helperText('Örn. yaşanan bir gecikmeyi telafi etmek için 10 gün.')
                            ->numeric()
                            ->minValue(0)
                            ->maxValue(365)
                            ->default(0)
                            ->live(onBlur: true)
                            ->visible(fn (Get $get) => $get('mode') === 'add'),

                        DatePicker::make('exact_date')
                            ->label('Yeni bitiş tarihi')
                            ->native(false)
                            ->displayFormat('d.m.Y')
                            ->default(fn () => $record->subscription_expires_at ?? now()->addMonth())
                            ->live()
                            ->visible(fn (Get $get) => $get('mode') === 'exact')
                            ->required(fn (Get $get) => $get('mode') === 'exact'),

                        Select::make('plan_id')
                            ->label('Paket')
                            ->helperText('Değiştirmek istemiyorsan olduğu gibi bırak.')
                            ->options(fn () => Plan::where('is_active', true)->orderBy('sort_order')->pluck('name', 'id'))
                            ->default(fn () => $record->plan_id)
                            ->native(false),

                        // Admin "uygula"ya basmadan sonucu görsün: tarih
                        // aritmetiğini kafadan yapmak hata kaynağıydı.
                        Placeholder::make('preview')
                            ->label('Sonuç')
                            ->content(function (Get $get) use ($record) {
                                $service = app(SubscriptionService::class);

                                if ($get('mode') === 'exact') {
                                    $result = $get('exact_date')
                                        ? Carbon::parse($get('exact_date'))
                                        : null;
                                } else {
                                    $result = $service->previewExtension(
                                        $record,
                                        (int) ($get('months') ?? 0),
                                        (int) ($get('days') ?? 0),
                                    );
                                }

                                if ($result === null) {
                                    return new HtmlString('<span class="text-gray-500">Tarih seç…</span>');
                                }

                                $remaining = (int) ceil(Carbon::now()->diffInDays($result, false));

                                return new HtmlString(sprintf(
                                    '<span class="font-semibold text-success-600">%s</span><br><span class="text-sm text-gray-500">Bugünden itibaren %d gün</span>',
                                    e($result->translatedFormat('d F Y')),
                                    max(0, $remaining),
                                ));
                            }),

                        Textarea::make('note')
                            ->label('Not (opsiyonel)')
                            ->helperText('Neden değişti? Denetim kaydına ve şirket notuna yazılır.')
                            ->rows(2),

                    ])
                    ->action(function (Company $record, array $data): void {
                        $service = app(SubscriptionService::class);
                        $previous = $record->subscription_expires_at;

                        $company = $service->apply(
                            $record,
                            months: $data['mode'] === 'add' ? (int) ($data['months'] ?? 0) : 0,
                            days: $data['mode'] === 'add' ? (int) ($data['days'] ?? 0) : 0,
                            planId: $data['plan_id'] ?? null,
                            exactDate: $data['mode'] === 'exact' ? Carbon::parse($data['exact_date']) : null,
                            note: $data['note'] ?? null,
                        );

                        // Süper-admin işlemi iz bırakmalı: kim, ne zaman,
                        // hangi tarihten hangi tarihe taşıdı.
                        $service->recordAdminAudit(
                            $company,
                            Auth::guard('admin')->user(),
                            'subscription.extended',
                            sprintf(
                                'Abonelik %s tarihine ayarlandı (önceki: %s)',
                                $company->subscription_expires_at?->format('d.m.Y') ?? '-',
                                $previous?->format('d.m.Y') ?? 'yok',
                            ),
                            ['mode' => $data['mode'], 'note' => $data['note'] ?? null],
                        );

                        // Bildirim HER ZAMAN gider (kullanıcı kararı):
                        // müşteri ödemesini yaptıktan sonra onayı bekliyor;
                        // haber verilmezse boşuna bekler ve destek arar.
                        $service->notifyChanged($company, $previous);

                        Notification::make()
                            ->title('Abonelik güncellendi')
                            ->body(($company->subscription_expires_at?->translatedFormat('d F Y') ?? '-').' tarihine kadar geçerli.')
                            ->success()
                            ->send();
                    }),
                EditAction::make(),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                ]),
            ]);
    }
}
