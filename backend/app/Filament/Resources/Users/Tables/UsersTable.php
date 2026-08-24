<?php

declare(strict_types=1);

namespace App\Filament\Resources\Users\Tables;

use App\Models\Company;
use App\Models\User;
use App\Services\UserTransferService;
use App\Support\RolePermissions;
use Filament\Actions\Action;
use Filament\Actions\ActionGroup;
use Filament\Actions\DeleteAction;
use Filament\Forms\Components\Checkbox;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Placeholder;
use Filament\Notifications\Notification;
use Filament\Support\Enums\FontWeight;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\HtmlString;
use Illuminate\Validation\ValidationException;

class UsersTable
{
    private static function roleOptions(): array
    {
        return collect(RolePermissions::ALL)
            ->mapWithKeys(fn (string $role) => [$role => RolePermissions::label($role)])
            ->all();
    }

    public static function configure(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn ($query) => $query->with('company'))
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('full_name')
                    ->label('Ad Soyad')
                    ->weight(FontWeight::SemiBold)
                    ->searchable(),
                TextColumn::make('email')
                    ->label('E-posta')
                    ->copyable()
                    ->copyMessage('E-posta kopyalandı')
                    ->searchable(),
                TextColumn::make('phone')
                    ->label('Telefon')
                    ->placeholder('—')
                    ->copyable()
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('company.name')
                    ->label('Şirket')
                    ->searchable()
                    ->sortable(),
                TextColumn::make('role')
                    ->label('Rol')
                    ->badge()
                    ->formatStateUsing(fn (?string $state) => RolePermissions::label((string) $state))
                    ->color(fn (?string $state) => $state === RolePermissions::OWNER ? 'success' : 'gray'),
                TextColumn::make('created_at')
                    ->label('Kayıt')
                    ->dateTime('d.m.Y')
                    ->sortable(),
            ])
            ->filters([
                SelectFilter::make('role')
                    ->label('Rol')
                    ->options(self::roleOptions()),
                SelectFilter::make('company_id')
                    ->label('Şirket')
                    ->relationship('company', 'name')
                    ->searchable()
                    ->preload(),
            ])
            ->recordActions([
                ActionGroup::make([
                    // Asıl destek senaryosu: kişi yanlışlıkla kendi
                    // şirketini açtı, çalıştığı firmaya taşınmalı.
                    Action::make('transfer')
                        ->label('Şirket Değiştir')
                        ->icon('heroicon-o-arrows-right-left')
                        ->color('warning')
                        ->modalHeading(fn (User $record) => 'Şirket değiştir — '.$record->full_name)
                        ->modalDescription('Kullanıcı hesabı başka bir şirkete taşınır. Oluşturduğu müşteri/iş kayıtları ESKİ şirkette kalır — onlar şirketin verisidir.')
                        ->schema(fn (User $record) => [
                            Placeholder::make('now')
                                ->label('Şu an')
                                ->content(new HtmlString(sprintf(
                                    '<span class="font-semibold">%s</span> · %s',
                                    e($record->company?->name ?? '-'),
                                    e(RolePermissions::label((string) $record->role)),
                                ))),
                            Select::make('company_id')
                                ->label('Yeni şirket')
                                ->options(fn () => Company::orderBy('name')->pluck('name', 'id'))
                                ->searchable()
                                ->required(),
                            Select::make('role')
                                ->label('Yeni şirketteki rolü')
                                ->options(self::roleOptions())
                                ->default(RolePermissions::TECHNICIAN)
                                ->native(false)
                                ->required(),
                            Checkbox::make('delete_empty_origin')
                                ->label('Eski şirket boş kalırsa sil')
                                ->helperText('Yalnızca hiç kullanıcısı ve hiç verisi kalmadıysa silinir; gerçek verisi olan şirket asla silinmez.')
                                ->default(true),
                        ])
                        ->action(function (User $record, array $data): void {
                            try {
                                app(UserTransferService::class)->transfer(
                                    $record,
                                    $data['company_id'],
                                    $data['role'],
                                    Auth::guard('admin')->user(),
                                    (bool) ($data['delete_empty_origin'] ?? false),
                                );
                            } catch (ValidationException $e) {
                                Notification::make()
                                    ->title('Taşınamadı')
                                    ->body(collect($e->errors())->flatten()->first())
                                    ->danger()
                                    ->persistent()
                                    ->send();

                                return;
                            }

                            Notification::make()
                                ->title('Kullanıcı taşındı')
                                ->body('Eski oturumları kapatıldı; yeniden giriş yapması gerekiyor.')
                                ->success()
                                ->send();
                        }),

                    Action::make('changeRole')
                        ->label('Rolü Değiştir')
                        ->icon('heroicon-o-key')
                        ->schema(fn (User $record) => [
                            Select::make('role')
                                ->label('Rol')
                                ->options(self::roleOptions())
                                ->default($record->role)
                                ->native(false)
                                ->required(),
                        ])
                        ->action(function (User $record, array $data): void {
                            // Şirketi sahipsiz bırakma.
                            $isLastOwner = $record->role === RolePermissions::OWNER
                                && User::where('company_id', $record->company_id)
                                    ->where('role', RolePermissions::OWNER)
                                    ->count() <= 1;

                            if ($isLastOwner && $data['role'] !== RolePermissions::OWNER) {
                                Notification::make()
                                    ->title('Değiştirilemedi')
                                    ->body('Bu kişi şirketin tek sahibi. Önce başka birini sahip yapmalısın.')
                                    ->danger()
                                    ->send();

                                return;
                            }

                            $record->update(['role' => $data['role']]);
                            $record->tokens()->delete(); // yeni yetkiyle yeniden giriş

                            Notification::make()->title('Rol güncellendi')->success()->send();
                        }),

                    DeleteAction::make()
                        ->label('Sil')
                        ->before(function (User $record, DeleteAction $action): void {
                            $isLastOwner = $record->role === RolePermissions::OWNER
                                && User::where('company_id', $record->company_id)
                                    ->where('role', RolePermissions::OWNER)
                                    ->count() <= 1;
                            $hasOthers = User::where('company_id', $record->company_id)
                                ->where('id', '!=', $record->id)
                                ->exists();

                            if ($isLastOwner && $hasOthers) {
                                Notification::make()
                                    ->title('Silinemedi')
                                    ->body('Bu kişi şirketin tek sahibi ve şirkette başka kullanıcılar var.')
                                    ->danger()
                                    ->send();

                                $action->cancel();
                            }
                        }),
                ]),
            ]);
    }
}
