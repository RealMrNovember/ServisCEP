@php
    $jobsByDay = $this->getUpcomingJobsByDay();

    $priorityColors = ['YUKSEK' => 'danger', 'NORMAL' => 'gray', 'DUSUK' => 'gray'];
@endphp

<x-filament-panels::page>
    @if (empty($jobsByDay))
        <x-filament::section>
            <p class="text-sm text-gray-500 dark:text-gray-400">Önümüzdeki 30 gün içinde randevulu iş bulunmuyor.</p>
        </x-filament::section>
    @else
        <div class="flex flex-col gap-y-4">
            @foreach ($jobsByDay as $day => $jobs)
                <x-filament::section :heading="\Illuminate\Support\Carbon::parse($day)->translatedFormat('d F Y, l')">
                    <div class="flex flex-col divide-y divide-gray-100 dark:divide-white/5">
                        @foreach ($jobs as $job)
                            <div class="flex items-center justify-between gap-x-4 py-3 first:pt-0 last:pb-0">
                                <div>
                                    <div class="font-medium">{{ $job->title }}</div>
                                    <div class="text-sm text-gray-500 dark:text-gray-400">
                                        {{ $job->customer?->display_name }}
                                        @if ($job->address)
                                            · {{ $job->address }}
                                        @endif
                                    </div>
                                </div>
                                <div class="flex items-center gap-x-2 whitespace-nowrap">
                                    <x-filament::badge :color="$priorityColors[$job->priority] ?? 'gray'">
                                        {{ $job->appointment_date->format('H:i') }}
                                    </x-filament::badge>
                                </div>
                            </div>
                        @endforeach
                    </div>
                </x-filament::section>
            @endforeach
        </div>
    @endif
</x-filament-panels::page>
