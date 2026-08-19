<?php

namespace App\Filament\App\Resources\Products\Tables;

use App\Models\Product;
use App\Models\StockMovement;
use Filament\Actions\Action;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Notifications\Notification;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Support\Facades\DB;

class ProductsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('name')
                    ->label('Ürün')
                    ->weight(FontWeight::SemiBold)
                    ->searchable(),
                TextColumn::make('barcode')
                    ->label('Barkod')
                    ->searchable()
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('category')
                    ->label('Kategori')
                    ->searchable(),
                TextColumn::make('current_stock')
                    ->label('Stok')
                    ->badge()
                    ->color(fn (Product $record) => $record->current_stock <= $record->min_stock ? 'danger' : 'success'),
                TextColumn::make('sale_price_minor')
                    ->label('Satış Fiyatı')
                    ->formatStateUsing(fn (?int $state) => number_format(($state ?? 0) / 100, 2, ',', '.').' ₺'),
            ])
            ->recordActions([
                Action::make('stockMovement')
                    ->label('Stok Hareketi')
                    ->icon('heroicon-o-arrows-up-down')
                    ->color('gray')
                    ->schema([
                        Select::make('type')
                            ->label('Hareket Tipi')
                            ->options(['IN' => 'Giriş', 'OUT' => 'Çıkış'])
                            ->required()
                            ->native(false),
                        TextInput::make('quantity')
                            ->label('Miktar')
                            ->numeric()
                            ->required()
                            ->minValue(1),
                        Textarea::make('note')
                            ->label('Not'),
                    ])
                    ->action(function (Product $record, array $data): void {
                        DB::transaction(function () use ($record, $data): void {
                            $product = Product::whereKey($record->id)->lockForUpdate()->first();

                            $delta = $data['type'] === 'OUT' ? -$data['quantity'] : $data['quantity'];
                            $product->current_stock = max(0, $product->current_stock + $delta);
                            $product->save();

                            StockMovement::create([
                                'product_id' => $product->id,
                                'type' => $data['type'],
                                'quantity' => $data['quantity'],
                                'reference_type' => 'manual_adjustment',
                                'note' => $data['note'] ?? null,
                            ]);
                        });

                        Notification::make()
                            ->title('Stok güncellendi')
                            ->success()
                            ->send();
                    }),
                EditAction::make(),
                DeleteAction::make(),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                ]),
            ]);
    }
}
