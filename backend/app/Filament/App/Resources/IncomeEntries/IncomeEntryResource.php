<?php

namespace App\Filament\App\Resources\IncomeEntries;

use App\Filament\App\Resources\IncomeEntries\Pages\CreateIncomeEntry;
use App\Filament\App\Resources\IncomeEntries\Pages\EditIncomeEntry;
use App\Filament\App\Resources\IncomeEntries\Pages\ListIncomeEntries;
use App\Filament\App\Resources\IncomeEntries\Schemas\IncomeEntryForm;
use App\Filament\App\Resources\IncomeEntries\Tables\IncomeEntriesTable;
use App\Models\IncomeEntry;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;

class IncomeEntryResource extends Resource
{
    protected static ?string $model = IncomeEntry::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedArrowTrendingUp;

    protected static ?string $modelLabel = 'Gelir';

    protected static ?string $pluralModelLabel = 'Gelirler';

    protected static ?string $navigationLabel = 'Gelirler';

    protected static string|\UnitEnum|null $navigationGroup = 'Finans';

    protected static ?int $navigationSort = 6;

    public static function form(Schema $schema): Schema
    {
        return IncomeEntryForm::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return IncomeEntriesTable::configure($table);
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
            'index' => ListIncomeEntries::route('/'),
            'create' => CreateIncomeEntry::route('/create'),
            'edit' => EditIncomeEntry::route('/{record}/edit'),
        ];
    }
}
