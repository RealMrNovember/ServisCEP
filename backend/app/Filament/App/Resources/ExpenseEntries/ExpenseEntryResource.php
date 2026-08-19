<?php

namespace App\Filament\App\Resources\ExpenseEntries;

use App\Filament\App\Resources\ExpenseEntries\Pages\CreateExpenseEntry;
use App\Filament\App\Resources\ExpenseEntries\Pages\EditExpenseEntry;
use App\Filament\App\Resources\ExpenseEntries\Pages\ListExpenseEntries;
use App\Filament\App\Resources\ExpenseEntries\Schemas\ExpenseEntryForm;
use App\Filament\App\Resources\ExpenseEntries\Tables\ExpenseEntriesTable;
use App\Models\ExpenseEntry;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;

class ExpenseEntryResource extends Resource
{
    protected static ?string $model = ExpenseEntry::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedArrowTrendingDown;

    protected static ?string $modelLabel = 'Gider';

    protected static ?string $pluralModelLabel = 'Giderler';

    protected static ?string $navigationLabel = 'Giderler';

    protected static string|\UnitEnum|null $navigationGroup = 'Finans';

    protected static ?int $navigationSort = 7;

    public static function form(Schema $schema): Schema
    {
        return ExpenseEntryForm::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return ExpenseEntriesTable::configure($table);
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
            'index' => ListExpenseEntries::route('/'),
            'create' => CreateExpenseEntry::route('/create'),
            'edit' => EditExpenseEntry::route('/{record}/edit'),
        ];
    }
}
