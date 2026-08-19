<?php

namespace App\Filament\App\Resources\Jobs;

use App\Filament\App\Resources\Jobs\Pages\CreateJob;
use App\Filament\App\Resources\Jobs\Pages\EditJob;
use App\Filament\App\Resources\Jobs\Pages\ListJobs;
use App\Filament\App\Resources\Jobs\Schemas\JobForm;
use App\Filament\App\Resources\Jobs\Tables\JobsTable;
use App\Models\Job;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;

class JobResource extends Resource
{
    protected static ?string $model = Job::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedWrenchScrewdriver;

    protected static ?string $modelLabel = 'İş / Talep';

    protected static ?string $pluralModelLabel = 'İşler / Talepler';

    protected static ?string $navigationLabel = 'İşler';

    protected static ?int $navigationSort = 2;

    public static function form(Schema $schema): Schema
    {
        return JobForm::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return JobsTable::configure($table);
    }

    public static function getRelations(): array
    {
        return [
            //
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListJobs::route('/'),
            'create' => CreateJob::route('/create'),
            'edit' => EditJob::route('/{record}/edit'),
        ];
    }
}
