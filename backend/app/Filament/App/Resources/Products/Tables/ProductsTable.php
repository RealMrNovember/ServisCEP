<?php

namespace App\Filament\App\Resources\Products\Tables;

use App\Models\Customer;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\Warranty;
use Filament\Actions\Action;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\DatePicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Notifications\Notification;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Support\Carbon;
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
                            ->live()
                            ->native(false),
                        TextInput::make('vendor_name')
                            ->label('Tedarikçi Firma')
                            ->helperText('Aynı ürün farklı tedarikçilerden alınabilir — her girişte ayrı kaydedilir.')
                            ->visible(fn ($get) => $get('type') === 'IN')
                            ->maxLength(255),
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
                                'vendor_name' => $data['type'] === 'IN' ? ($data['vendor_name'] ?? null) : null,
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
                Action::make('createWarranty')
                    ->label('Garanti Oluştur')
                    ->icon('heroicon-o-shield-check')
                    ->color('success')
                    ->modalHeading(fn (Product $record) => "Garanti Oluştur — {$record->name}")
                    ->schema(fn (Product $record) => [
                        Select::make('customer_id')
                            ->label('Müşteri')
                            ->helperText('Bu cihazı monte ettiğiniz müşteriyi seçin ya da yeni müşteri oluşturun.')
                            ->options(fn () => Customer::query()->get()->pluck('display_name', 'id'))
                            ->searchable()
                            ->required()
                            ->createOptionForm([
                                TextInput::make('contact_name')
                                    ->label('Yetkili Adı Soyadı')
                                    ->requiredWithout('company_name'),
                                TextInput::make('company_name')
                                    ->label('Firma Adı')
                                    ->requiredWithout('contact_name'),
                                TextInput::make('phone')
                                    ->label('Telefon')
                                    ->tel(),
                            ])
                            ->createOptionUsing(function (array $data): string {
                                $customer = Customer::create([
                                    'code' => 'MUS-'.str_pad((string) (Customer::withTrashed()->count() + 1), 4, '0', STR_PAD_LEFT),
                                    'contact_name' => $data['contact_name'] ?? null,
                                    'company_name' => $data['company_name'] ?? null,
                                    'phone' => $data['phone'] ?? null,
                                    'type' => 'BIREYSEL',
                                ]);

                                return $customer->id;
                            }),
                        DatePicker::make('install_date')
                            ->label('Montaj Tarihi')
                            ->native(false)
                            ->default(now())
                            ->required(),
                        TextInput::make('warranty_months')
                            ->label('Garanti Süresi (ay)')
                            ->numeric()
                            ->default(12)
                            ->required(),
                        TextInput::make('serial_number')
                            ->label('Seri No'),
                        TextInput::make('quantity')
                            ->label('Stoktan Düşülecek Miktar')
                            ->helperText(fn (Product $record) => "Mevcut stok: {$record->current_stock}")
                            ->numeric()
                            ->default(1)
                            ->required()
                            ->minValue(1)
                            ->maxValue(fn (Product $record) => max(1, $record->current_stock)),
                        Textarea::make('notes')
                            ->label('Not')
                            ->columnSpanFull(),
                    ])
                    ->action(function (Product $record, array $data): void {
                        DB::transaction(function () use ($record, $data): void {
                            $product = Product::whereKey($record->id)->lockForUpdate()->first();

                            $product->current_stock = max(0, $product->current_stock - $data['quantity']);
                            $product->save();

                            $warranty = Warranty::create([
                                'customer_id' => $data['customer_id'],
                                'product_id' => $product->id,
                                'item_description' => $product->name,
                                'serial_number' => $data['serial_number'] ?? null,
                                'install_date' => $data['install_date'],
                                'warranty_months' => $data['warranty_months'],
                                'warranty_expires_at' => Carbon::parse($data['install_date'])->addMonths((int) $data['warranty_months']),
                                'notes' => $data['notes'] ?? null,
                            ]);

                            StockMovement::create([
                                'product_id' => $product->id,
                                'type' => 'OUT',
                                'quantity' => $data['quantity'],
                                'reference_type' => 'warranty',
                                'reference_id' => $warranty->id,
                                'note' => "Müşteriye montaj — garanti kaydı oluşturuldu.",
                            ]);
                        });

                        Notification::make()
                            ->title('Garanti oluşturuldu, stok güncellendi')
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
