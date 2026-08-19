<?php

namespace App\Filament\App\Resources\Proformas;

use App\Filament\App\Resources\Proformas\Pages\CreateProforma;
use App\Filament\App\Resources\Proformas\Pages\EditProforma;
use App\Filament\App\Resources\Proformas\Pages\ListProformas;
use App\Filament\App\Resources\Proformas\Schemas\ProformaForm;
use App\Filament\App\Resources\Proformas\Tables\ProformasTable;
use App\Models\Proforma;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;

class ProformaResource extends Resource
{
    protected static ?string $model = Proforma::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedDocumentDuplicate;

    protected static ?string $modelLabel = 'Proforma';

    protected static ?string $pluralModelLabel = 'Proformalar';

    protected static ?string $navigationLabel = 'Proformalar';

    protected static string|\UnitEnum|null $navigationGroup = 'Ticari Belgeler';

    protected static ?int $navigationSort = 4;

    public static function form(Schema $schema): Schema
    {
        return ProformaForm::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return ProformasTable::configure($table);
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
            'index' => ListProformas::route('/'),
            'create' => CreateProforma::route('/create'),
            'edit' => EditProforma::route('/{record}/edit'),
        ];
    }
}
