@php
    $company = \Filament\Facades\Filament::auth()->user()->company;
    $bank = $this->getBankSettings();
    $requests = $this->getMyRequests();

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

    <form wire:submit="submit">
        {{ $this->form }}

        <div class="mt-6">
            <x-filament::button type="submit">
                Ödeme Talebi Gönder
            </x-filament::button>
        </div>
    </form>

    <x-filament::section heading="Geçmiş Ödeme Talepleri">
        @if ($requests->isEmpty())
            <p class="text-sm text-gray-500 dark:text-gray-400">Henüz bir ödeme talebiniz yok.</p>
        @else
            <div class="overflow-x-auto">
                <table class="w-full text-sm">
                    <thead>
                        <tr class="border-b border-gray-200 text-left dark:border-white/10">
                            <th class="py-2 pr-4">Tarih</th>
                            <th class="py-2 pr-4">Paket</th>
                            <th class="py-2 pr-4">Tutar</th>
                            <th class="py-2 pr-4">Durum</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($requests as $request)
                            <tr class="border-b border-gray-100 dark:border-white/5">
                                <td class="py-2 pr-4">{{ $request->created_at?->format('d.m.Y H:i') }}</td>
                                <td class="py-2 pr-4">{{ $request->plan?->name ?? '—' }}</td>
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
