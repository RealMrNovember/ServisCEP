@php
    $company = $this->getCurrentCompany();
    $bank = $this->getBankSettings();
    $requests = $this->getMyRequests();
    $plans = $this->getPlans();

    $daysRemaining = $company->subscription_expires_at ? max(0, (int) now()->diffInDays($company->subscription_expires_at, false)) : null;
    $isActive = $company->hasActiveSubscription();

    $statusLabels = [
        'PENDING' => ['Bekliyor', 'warning'],
        'APPROVED' => ['Onaylandı', 'success'],
        'REJECTED' => ['Reddedildi', 'danger'],
    ];
@endphp

<x-filament-panels::page>
    {{-- Abonelik Durumu --}}
    <div class="overflow-hidden rounded-2xl border border-gray-200 bg-gradient-to-br from-white to-gray-50 dark:border-white/10 dark:from-gray-900 dark:to-gray-950">
        <div class="p-6 sm:p-8">
            <div class="flex flex-col gap-6 sm:flex-row sm:items-center sm:justify-between">
                <div class="flex items-center gap-4">
                    <div class="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-primary-50 text-primary-600 dark:bg-primary-500/10 dark:text-primary-400">
                        <x-filament::icon icon="heroicon-o-shield-check" class="h-7 w-7" />
                    </div>
                    <div>
                        <div class="text-sm font-medium text-gray-500 dark:text-gray-400">Aktif Paketiniz</div>
                        <div class="text-2xl font-bold tracking-tight">{{ $company->plan?->name ?? 'Paket Seçilmedi' }}</div>
                    </div>
                </div>
                <x-filament::badge :color="$isActive ? 'success' : 'danger'" size="lg">
                    <div class="flex items-center gap-x-1.5">
                        <span class="h-1.5 w-1.5 rounded-full {{ $isActive ? 'bg-success-500' : 'bg-danger-500' }}"></span>
                        {{ $isActive ? 'Aktif' : 'Pasif' }}
                    </div>
                </x-filament::badge>
            </div>

            <div class="mt-6 grid grid-cols-1 gap-6 border-t border-gray-200 pt-6 sm:grid-cols-3 dark:border-white/10">
                <div>
                    <div class="text-xs font-semibold uppercase tracking-wide text-gray-400 dark:text-gray-500">Bitiş Tarihi</div>
                    <div class="mt-1 text-lg font-semibold">
                        {{ $company->subscription_expires_at?->format('d.m.Y H:i') ?? 'Süresiz' }}
                    </div>
                </div>
                <div>
                    <div class="text-xs font-semibold uppercase tracking-wide text-gray-400 dark:text-gray-500">Kalan Süre</div>
                    <div class="mt-1 text-lg font-semibold">
                        @if ($daysRemaining === null)
                            —
                        @elseif ($daysRemaining <= 0)
                            <span class="text-danger-600 dark:text-danger-400">Süresi doldu</span>
                        @else
                            {{ $daysRemaining }} gün
                        @endif
                    </div>
                    @if ($daysRemaining !== null && $company->plan?->duration_days)
                        @php $pct = max(0, min(100, (int) round(($daysRemaining / $company->plan->duration_days) * 100))); @endphp
                        <div class="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-gray-100 dark:bg-white/10">
                            <div class="h-full rounded-full {{ $pct <= 15 ? 'bg-danger-500' : ($pct <= 40 ? 'bg-warning-500' : 'bg-success-500') }}" style="width: {{ $pct }}%"></div>
                        </div>
                    @endif
                </div>
                <div>
                    <div class="text-xs font-semibold uppercase tracking-wide text-gray-400 dark:text-gray-500">Kullanıcı</div>
                    <div class="mt-1 text-lg font-semibold">
                        {{ $company->users()->count() }}{{ $company->plan?->max_users ? ' / '.$company->plan->max_users : ' (sınırsız)' }}
                    </div>
                </div>
            </div>
        </div>
    </div>

    {{-- Paketler --}}
    <x-filament::section>
        <x-slot name="heading">
            <span class="text-xl font-bold">Paketler</span>
        </x-slot>
        <x-slot name="description">
            İhtiyacınıza uygun paketi seçin — ödemeyi yaptıktan sonra aşağıdaki formla bildirin, onaylandığında aboneliğiniz otomatik uzatılır.
        </x-slot>

        <div class="grid grid-cols-1 gap-6 md:grid-cols-3">
            @foreach ($plans as $plan)
                @php
                    $isCurrent = $company->plan_id === $plan->id;
                    $isPopular = $plan->slug === 'profesyonel';
                    $savings = $this->getYearlySavingsPercent($plan);
                    $parsed = $this->splitPlanDescription($plan);
                    $icon = match ($plan->slug) {
                        'baslangic' => 'heroicon-o-rocket-launch',
                        'profesyonel' => 'heroicon-o-bolt',
                        'kurumsal' => 'heroicon-o-building-office-2',
                        default => 'heroicon-o-cube',
                    };
                @endphp
                <div @class([
                    'relative flex flex-col rounded-2xl border bg-white p-6 shadow-sm transition hover:shadow-lg dark:bg-gray-900',
                    'border-primary-500 ring-2 ring-primary-500' => $isCurrent,
                    'border-gray-200 dark:border-white/10' => ! $isCurrent,
                ])>
                    @if ($isCurrent)
                        <span class="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-primary-600 px-3 py-1 text-xs font-semibold whitespace-nowrap text-white shadow">
                            Mevcut Paketiniz
                        </span>
                    @elseif ($isPopular)
                        <span class="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-gray-900 px-3 py-1 text-xs font-semibold whitespace-nowrap text-white shadow dark:bg-white dark:text-gray-900">
                            ⭐ En Popüler
                        </span>
                    @endif

                    <div class="flex items-center gap-3">
                        <div class="flex h-11 w-11 items-center justify-center rounded-xl bg-primary-50 text-primary-600 dark:bg-primary-500/10 dark:text-primary-400">
                            <x-filament::icon :icon="$icon" class="h-6 w-6" />
                        </div>
                        <div class="text-lg font-bold">{{ $plan->name }}</div>
                    </div>

                    <div class="mt-5 flex items-baseline gap-x-1">
                        <span class="text-4xl font-extrabold tracking-tight">
                            {{ number_format($plan->price_minor / 100, 0, ',', '.') }} ₺
                        </span>
                        <span class="text-sm font-medium text-gray-500 dark:text-gray-400">/ ay</span>
                    </div>
                    <div class="mt-1 flex items-center gap-x-2 text-sm text-gray-500 dark:text-gray-400">
                        <span>veya yıllık {{ number_format($plan->price_yearly_minor / 100, 0, ',', '.') }} ₺</span>
                        @if ($savings > 0)
                            <span class="rounded-full bg-success-50 px-2 py-0.5 text-xs font-semibold text-success-700 dark:bg-success-500/10 dark:text-success-400">
                                %{{ $savings }} tasarruf
                            </span>
                        @endif
                    </div>

                    @if ($parsed['audience'])
                        <p class="mt-4 text-sm font-medium text-gray-700 dark:text-gray-300">{{ $parsed['audience'] }}.</p>
                    @endif

                    <ul class="mt-4 flex-1 space-y-2.5">
                        @foreach ($parsed['features'] as $feature)
                            <li class="flex items-start gap-x-2 text-sm text-gray-600 dark:text-gray-300">
                                <x-filament::icon icon="heroicon-o-check-circle" class="mt-0.5 h-4 w-4 shrink-0 text-success-500" />
                                <span>{{ $feature }}</span>
                            </li>
                        @endforeach
                        <li class="flex items-start gap-x-2 text-sm font-medium text-gray-700 dark:text-gray-200">
                            <x-filament::icon icon="heroicon-o-users" class="mt-0.5 h-4 w-4 shrink-0 text-primary-500" />
                            <span>{{ $plan->max_users ? "Maksimum {$plan->max_users} kullanıcı" : 'Sınırsız kullanıcı' }}</span>
                        </li>
                    </ul>

                    <div class="mt-6 grid grid-cols-2 gap-2">
                        <x-filament::button
                            :color="$isCurrent ? 'gray' : 'primary'"
                            outlined
                            class="justify-center"
                            wire:click="selectPlan('{{ $plan->id }}', 'MONTHLY')"
                        >
                            Aylık Seç
                        </x-filament::button>
                        <x-filament::button
                            :color="$isCurrent ? 'gray' : 'primary'"
                            class="justify-center"
                            wire:click="selectPlan('{{ $plan->id }}', 'YEARLY')"
                        >
                            Yıllık Seç
                        </x-filament::button>
                    </div>
                </div>
            @endforeach
        </div>
    </x-filament::section>

    {{-- Havale/EFT Bilgileri --}}
    <x-filament::section>
        <x-slot name="heading">
            <div class="flex items-center gap-x-2">
                <x-filament::icon icon="heroicon-o-banknotes" class="h-5 w-5 text-primary-500" />
                <span>Havale/EFT Bilgileri</span>
            </div>
        </x-slot>
        <x-slot name="description">
            Ödemenizi aşağıdaki hesaba yaptıktan sonra alttaki formla ödeme talebi oluşturun.
        </x-slot>

        @if ($bank['iban'])
            <div
                x-data="{ copied: false }"
                class="grid grid-cols-1 gap-4 rounded-xl bg-gray-50 p-4 sm:grid-cols-3 dark:bg-white/5"
            >
                <div>
                    <div class="text-xs font-semibold uppercase tracking-wide text-gray-400 dark:text-gray-500">IBAN</div>
                    <div class="mt-1 flex items-center gap-x-2">
                        <span class="font-mono text-base font-semibold">{{ $bank['iban'] }}</span>
                        <button
                            type="button"
                            x-on:click="navigator.clipboard.writeText('{{ $bank['iban'] }}'); copied = true; setTimeout(() => copied = false, 1500)"
                            class="text-gray-400 hover:text-primary-500"
                            title="Kopyala"
                        >
                            <span x-show="!copied">
                                <x-filament::icon icon="heroicon-o-clipboard-document" class="h-4 w-4" />
                            </span>
                            <span x-show="copied" x-cloak>
                                <x-filament::icon icon="heroicon-o-check" class="h-4 w-4 text-success-500" />
                            </span>
                        </button>
                    </div>
                </div>
                <div>
                    <div class="text-xs font-semibold uppercase tracking-wide text-gray-400 dark:text-gray-500">Hesap Sahibi</div>
                    <div class="mt-1 text-base font-semibold">{{ $bank['account_holder'] }}</div>
                </div>
                <div>
                    <div class="text-xs font-semibold uppercase tracking-wide text-gray-400 dark:text-gray-500">Banka</div>
                    <div class="mt-1 text-base font-semibold">{{ $bank['bank_name'] }}</div>
                </div>
            </div>
            @if ($bank['note'])
                <p class="mt-4 text-sm text-gray-500 dark:text-gray-400">{{ $bank['note'] }}</p>
            @endif
        @else
            <p class="text-sm text-gray-500 dark:text-gray-400">Ödeme bilgileri henüz tanımlanmadı.</p>
        @endif
    </x-filament::section>

    {{-- Ödeme Talebi Formu --}}
    <div x-data x-on:plan-selected.window="$el.scrollIntoView({ behavior: 'smooth', block: 'start' })">
        <x-filament::section>
            <x-slot name="heading">
                <div class="flex items-center gap-x-2">
                    <x-filament::icon icon="heroicon-o-paper-airplane" class="h-5 w-5 text-primary-500" />
                    <span>Yeni Ödeme Talebi</span>
                </div>
            </x-slot>
            <x-slot name="description">
                Yukarıdan bir paket seçtiğinizde bu form otomatik doldurulur; isterseniz elle de değiştirebilirsiniz.
            </x-slot>

            <form wire:submit="submit">
                {{ $this->form }}

                <div class="mt-6">
                    <x-filament::button type="submit" icon="heroicon-o-paper-airplane">
                        Ödeme Talebi Gönder
                    </x-filament::button>
                </div>
            </form>
        </x-filament::section>
    </div>

    {{-- Geçmiş --}}
    <x-filament::section heading="Geçmiş Ödeme Talepleri">
        @if ($requests->isEmpty())
            <div class="flex flex-col items-center justify-center py-8 text-center">
                <x-filament::icon icon="heroicon-o-inbox" class="h-10 w-10 text-gray-300 dark:text-gray-600" />
                <p class="mt-3 text-sm text-gray-500 dark:text-gray-400">Henüz bir ödeme talebiniz yok.</p>
            </div>
        @else
            <div class="overflow-x-auto">
                <table class="w-full text-sm">
                    <thead>
                        <tr class="border-b border-gray-200 text-left dark:border-white/10">
                            <th class="py-2 pr-4 font-semibold text-gray-500 dark:text-gray-400">Tarih</th>
                            <th class="py-2 pr-4 font-semibold text-gray-500 dark:text-gray-400">Talep Edilen Paket</th>
                            <th class="py-2 pr-4 font-semibold text-gray-500 dark:text-gray-400">Onaylanan Paket</th>
                            <th class="py-2 pr-4 font-semibold text-gray-500 dark:text-gray-400">Tutar</th>
                            <th class="py-2 pr-4 font-semibold text-gray-500 dark:text-gray-400">Durum</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($requests as $request)
                            <tr class="border-b border-gray-100 dark:border-white/5">
                                <td class="py-3 pr-4">{{ $request->created_at?->format('d.m.Y H:i') }}</td>
                                <td class="py-3 pr-4">{{ $request->plan?->name ?? '—' }}</td>
                                <td class="py-3 pr-4">{{ $request->approvedPlan?->name ?? '—' }}</td>
                                <td class="py-3 pr-4 font-medium">
                                    {{ $request->claimed_amount_minor ? number_format($request->claimed_amount_minor / 100, 2, ',', '.').' ₺' : '—' }}
                                </td>
                                <td class="py-3 pr-4">
                                    <x-filament::badge :color="$statusLabels[$request->status][1] ?? 'gray'">
                                        {{ $statusLabels[$request->status][0] ?? $request->status }}
                                    </x-filament::badge>
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        @endif
    </x-filament::section>
</x-filament-panels::page>
