<?php

namespace App\Filament\App\Pages;

use App\Models\Job;
use BackedEnum;
use Filament\Pages\Page;
use Filament\Support\Icons\Heroicon;
use Illuminate\Support\Carbon;

/**
 * Randevu takvimi — MVP kapsamında ay/hafta ızgarası yerine, önümüzdeki
 * randevuları gün gün listeleyen sade bir görünüm (bkz. Job.appointment_date).
 */
class Calendar extends Page
{
    protected string $view = 'filament.app.pages.calendar';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedCalendarDays;

    protected static ?string $navigationLabel = 'Takvim';

    protected static ?string $title = 'Takvim';

    protected static ?int $navigationSort = 8;

    public function getUpcomingJobsByDay(): array
    {
        $jobs = Job::query()
            ->whereNotNull('appointment_date')
            ->where('appointment_date', '>=', Carbon::now()->startOfDay())
            ->where('appointment_date', '<=', Carbon::now()->addDays(30)->endOfDay())
            ->orderBy('appointment_date')
            ->with('customer')
            ->get();

        return $jobs->groupBy(fn (Job $job) => $job->appointment_date->format('Y-m-d'))->all();
    }
}
