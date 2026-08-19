<?php

namespace App\Filament\Resources\Plans\Schemas;

use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Schema;
use Illuminate\Support\Str;

class PlanForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('name')
                    ->label('Paket Adı')
                    ->required()
                    ->live(onBlur: true)
                    ->afterStateUpdated(fn (string $context, $state, callable $set) => $context === 'create' ? $set('slug', Str::slug($state)) : null),
                TextInput::make('slug')
                    ->label('Slug')
                    ->required()
                    ->unique(ignoreRecord: true),
                Textarea::make('description')
                    ->label('Açıklama')
                    ->columnSpanFull(),
                TextInput::make('price_minor')
                    ->label('Aylık Fiyat (₺)')
                    ->numeric()
                    ->step(0.01)
                    ->minValue(0)
                    ->default(0)
                    ->required()
                    ->dehydrateStateUsing(fn ($state) => (int) round(((float) $state) * 100))
                    ->afterStateHydrated(function (TextInput $component, $state) {
                        $component->state(is_numeric($state) ? $state / 100 : 0);
                    }),
                TextInput::make('price_yearly_minor')
                    ->label('Yıllık Fiyat (₺)')
                    ->helperText('Genelde 12 aylık fiyattan indirimli olur.')
                    ->numeric()
                    ->step(0.01)
                    ->minValue(0)
                    ->default(0)
                    ->required()
                    ->dehydrateStateUsing(fn ($state) => (int) round(((float) $state) * 100))
                    ->afterStateHydrated(function (TextInput $component, $state) {
                        $component->state(is_numeric($state) ? $state / 100 : 0);
                    }),
                TextInput::make('duration_days')
                    ->label('Süre (gün)')
                    ->helperText('Bu pakete geçen bir şirketin abonelik süresi kaç gün olsun.')
                    ->numeric(),
                TextInput::make('max_users')
                    ->label('Maksimum kullanıcı')
                    ->helperText('Boş = sınırsız')
                    ->numeric(),
                Toggle::make('is_active')
                    ->label('Aktif (satışta)')
                    ->required()
                    ->default(true),
                TextInput::make('sort_order')
                    ->label('Sıralama')
                    ->required()
                    ->numeric()
                    ->default(0),
            ]);
    }
}
