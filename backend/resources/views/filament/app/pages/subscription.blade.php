@php
    $company = $this->getCurrentCompany();
    $bank = $this->getBankSettings();
    $requests = $this->getMyRequests();
    $plans = $this->getPlans();

    $statusLabels = [
        'PENDING' => ['Bekliyor', 'warning'],
        'APPROVED' => ['Onaylandı', 'success'],
        'REJECTED' => ['Reddedildi', 'danger'],
    ];
@endphp

<x-filament-panels::page>
    <x-filament::section heading="Mevcut Abonelik">
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
            <div>
                <div class="text-sm text-gray-500 dark:text-gray-400">Paket</div>
                <div class="text-base font-semibold">{{ $company->plan?->name ?? '—' }}</div>
            </div>
            <div>
                <div class="text-sm text-gray-500 dark:text-gray-400">Bitiş Tarihi</div>
                <div class="text-base font-semibold">
                    {{ $company->subscription_expires_at?->format('d.m.Y H:i') ?? 'Süresiz' }}
                </div>
            </div>
            <div>
                <div class="text-sm text-gray-500 dark:text-gray-400">Durum</div>
                <x-filament::badge :color="$company->hasActiveSubscription() ? 'success' : 'danger'">
                    {{ $company->hasActiveSubscription() ? 'Aktif' : 'Pasif' }}
                </x-filament::badge>
            </div>
        </div>
    </x-filament::section>

    <x-filament::section heading="Paketler" description="İhtiyacınıza uygun paketi seçin — ödemeyi yaptıktan sonra aşağıdaki formla bildirin, onaylandığında aboneliğiniz otomatik uzatılır.">
        <div class="grid grid-cols-1 gap-5 md:grid-cols-3">
            @foreach ($plans as $plan)
                @php $isCurrent = $company->plan_id === $plan->id; @endphp
                <div class="relative flex flex-col rounded-xl border p-5 {{ $isCurrent ? 'border-primary-500 ring-1 ring-primary-500' : 'border-gray-200 dark:border-white/10' }}">
                    @if ($isCurrent)
                        <span class="absolute -top-3 left-4 rounded-full bg-primary-600 px-3 py-1 text-xs font-semibold text-white">
                            Mevcut Paketiniz
                        </span>
                    @endif

                    <div class="text-lg font-bold">{{ $plan->name }}</div>

                    <div class="mt-3 flex items-baseline gap-x-1">
                        <span class="text-3xl font-extrabold tracking-tight">
                            {{ number_format($plan->price_minor / 100, 0, ',', '.') }} ₺
                        </span>
                        <span class="text-sm text-gray-500 dark:text-gray-400">/ ay</span>
                    </div>
                    <div class="text-sm text-gray-500 dark:text-gray-400">
                        veya yıllık {{ number_format($plan->price_yearly_minor / 100, 0, ',', '.') }} ₺
                    </div>

                    <p class="mt-4 flex-1 text-sm text-gray-600 dark:text-gray-300">
                        {{ $plan->description }}
                    </p>

                    <div class="mt-4 text-sm font-medium text-gray-500 dark:text-gray-400">
                        {{ $plan->max_users ? "Maksimum {$plan->max_users} kullanıcı" : 'Sınırsız kullanıcı' }}
                    </div>

                    <x-filament::button
                        :color="$isCurrent ? 'gray' : 'primary'"
                        class="mt-5 w-full justify-center"
                        wire:click="selectPlan('{{ $plan->id }}')"
                    >
                        {{ $isCurrent ? 'Bu Paketi Yenile' : 'Bu Paketi Seç' }}
                    </x-filament::button>
                </div>
            @endforeach
        </div>
    </x-filament::section>

    <x-filament::section heading="Havale/EFT Bilgileri" description="Ödemenizi aşağıdaki hesaba yaptıktan sonra alttaki formla ödeme talebi oluşturun.">
        @if ($bank['iban'])
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
                <div>
                    <div class="text-sm text-gray-500 dark:text-gray-400">IBAN</div>
                    <div class="text-base font-semibold">{{ $bank['iban'] }}</div>
                </div>
                <div>
                    <div class="text-sm text-gray-500 dark:text-gray-400">Hesap Sahibi</div>
                    <div class="text-base font-semibold">{{ $bank['account_holder'] }}</div>
                </div>
                <div>
                    <div class="text-sm text-gray-500 dark:text-gray-400">Banka</div>
                    <div class="text-base font-semibold">{{ $bank['bank_name'] }}</div>
                </div>
            </div>
            @if ($bank['note'])
                <p class="mt-4 text-sm text-gray-500 dark:text-gray-400">{{ $bank['note'] }}</p>
            @endif
        @else
            <p class="text-sm text-gray-500 dark:text-gray-400">Ödeme bilgileri henüz tanımlanmadı.</p>
        @endif
    </x-filament::section>

    <div x-data x-on:plan-selected.window="$el.scrollIntoView({ behavior: 'smooth', block: 'start' })">
        <x-filament::section heading="Yeni Ödeme Talebi" description="Yukarıdan bir paket seçtiğinizde bu form otomatik doldurulur; isterseniz elle de değiştirebilirsiniz.">
            <form wire:submit="submit">
                {{ $this->form }}

                <div class="mt-6">
                    <x-filament::button type="submit">
                        Ödeme Talebi Gönder
                    </x-filament::button>
                </div>
            </form>
        </x-filament::section>
    </div>

    <x-filament::section heading="Geçmiş Ödeme Talepleri">
        @if ($requests->isEmpty())
            <p class="text-sm text-gray-500 dark:text-gray-400">Henüz bir ödeme talebiniz yok.</p>
        @else
            <div class="overflow-x-auto">
                <table class="w-full text-sm">
                    <thead>
                        <tr class="border-b border-gray-200 text-left dark:border-white/10">
                            <th class="py-2 pr-4">Tarih</th>
                            <th class="py-2 pr-4">Talep Edilen Paket</th>
                            <th class="py-2 pr-4">Onaylanan Paket</th>
                            <th class="py-2 pr-4">Tutar</th>
                            <th class="py-2 pr-4">Durum</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($requests as $request)
                            <tr class="border-b border-gray-100 dark:border-white/5">
                                <td class="py-2 pr-4">{{ $request->created_at?->format('d.m.Y H:i') }}</td>
                                <td class="py-2 pr-4">{{ $request->plan?->name ?? '—' }}</td>
                                <td class="py-2 pr-4">{{ $request->approvedPlan?->name ?? '—' }}</td>
                                <td class="py-2 pr-4">
                                    {{ $request->claimed_amount_minor ? number_format($request->claimed_amount_minor / 100, 2, ',', '.').' ₺' : '—' }}
                                </td>
                                <td class="py-2 pr-4">
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
