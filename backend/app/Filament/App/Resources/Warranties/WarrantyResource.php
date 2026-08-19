<?php

namespace App\Filament\App\Resources\Warranties;

use App\Filament\App\Resources\Warranties\Pages\CreateWarranty;
use App\Filament\App\Resources\Warranties\Pages\EditWarranty;
use App\Filament\App\Resources\Warranties\Pages\ListWarranties;
use App\Filament\App\Resources\Warranties\Schemas\WarrantyForm;
use App\Filament\App\Resources\Warranties\Tables\WarrantiesTable;
use App\Models\Warranty;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;

class WarrantyResource extends Resource
{
    protected static ?string $model = Warranty::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedShieldCheck;

    protected static ?string $modelLabel = 'Garanti';

    protected static ?string $pluralModelLabel = 'Garantiler';

    protected static ?string $navigationLabel = 'Garantiler';

    protected static ?int $navigationSort = 6;

    public static function form(Schema $schema): Schema
    {
        return WarrantyForm::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return WarrantiesTable::configure($table);
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
            'index' => ListWarranties::route('/'),
            'create' => CreateWarranty::route('/create'),
            'edit' => EditWarranty::route('/{record}/edit'),
        ];
    }
}
