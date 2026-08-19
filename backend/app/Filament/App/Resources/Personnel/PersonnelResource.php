<?php

namespace App\Filament\App\Resources\Personnel;

use App\Filament\App\Resources\Personnel\Pages\CreatePersonnel;
use App\Filament\App\Resources\Personnel\Pages\EditPersonnel;
use App\Filament\App\Resources\Personnel\Pages\ListPersonnel;
use App\Filament\App\Resources\Personnel\Schemas\PersonnelForm;
use App\Filament\App\Resources\Personnel\Tables\PersonnelTable;
use App\Models\User;
use BackedEnum;
use Filament\Facades\Filament;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

/**
 * Şirket sahibinin kendi ekibine (aynı company_id altına) kullanıcı
 * ekleyip yönetebildiği ekran — User modelinde BelongsToCompany trait'i
 * yok (kimlik doğrulayan taraf o), bu yüzden sorgu burada elle
 * company_id'ye kısıtlanır.
 */
class PersonnelResource extends Resource
{
    protected static ?string $model = User::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedUserGroup;

    protected static ?string $modelLabel = 'Personel';

    protected static ?string $pluralModelLabel = 'Personel';

    protected static ?string $navigationLabel = 'Personel';

    protected static ?int $navigationSort = 9;

    protected static ?string $slug = 'personel';

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()
            ->where('company_id', Filament::auth()->user()->company_id);
    }

    public static function form(Schema $schema): Schema
    {
        return PersonnelForm::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return PersonnelTable::configure($table);
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
            'index' => ListPersonnel::route('/'),
            'create' => CreatePersonnel::route('/create'),
            'edit' => EditPersonnel::route('/{record}/edit'),
        ];
    }
}
