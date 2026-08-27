<?php

namespace App\Filament\Resources\Feedbacks;

use App\Filament\Resources\Feedbacks\Pages\EditFeedback;
use App\Filament\Resources\Feedbacks\Pages\ListFeedbacks;
use App\Filament\Resources\Feedbacks\Schemas\FeedbackForm;
use App\Filament\Resources\Feedbacks\Tables\FeedbacksTable;
use App\Models\Feedback;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;

class FeedbackResource extends Resource
{
    protected static ?string $model = Feedback::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedChatBubbleLeftRight;

    protected static ?string $modelLabel = 'Geri Bildirim';

    protected static ?string $pluralModelLabel = 'Geri Bildirimler';

    protected static ?string $navigationLabel = 'Geri Bildirimler';

    protected static ?int $navigationSort = 3;

    public static function form(Schema $schema): Schema
    {
        return FeedbackForm::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return FeedbacksTable::configure($table);
    }

    /**
     * Menüde bekleyen sayısı.
     *
     * Rozet olmadan geri bildirim kutusu, girilmediği sürece görünmez bir
     * kutudur — kullanıcı cevap beklerken kimse farkında olmaz.
     */
    public static function getNavigationBadge(): ?string
    {
        $count = static::getModel()::query()
            ->whereIn('status', ['YENI', 'INCELENIYOR'])
            ->count();

        return $count > 0 ? (string) $count : null;
    }

    public static function getNavigationBadgeColor(): ?string
    {
        return 'warning';
    }

    public static function getPages(): array
    {
        return [
            'index' => ListFeedbacks::route('/'),
            'edit' => EditFeedback::route('/{record}/edit'),
        ];
    }
}
