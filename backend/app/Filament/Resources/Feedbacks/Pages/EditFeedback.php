<?php

namespace App\Filament\Resources\Feedbacks\Pages;

use App\Filament\Resources\Feedbacks\FeedbackResource;
use Filament\Resources\Pages\EditRecord;

class EditFeedback extends EditRecord
{
    protected static string $resource = FeedbackResource::class;

    protected function getHeaderActions(): array
    {
        // Silme YOK. Geri bildirim, hoşa gitmediğinde kaldırılabilecek bir
        // kayıt değil; kapatılabilir ama yok edilemez.
        return [];
    }

    /**
     * Yanıt yazıldığında kullanıcıya BİLDİRİM gider.
     *
     * Panelde kalan bir cevap, cevap değildir: kullanıcı geri bildirimini
     * gönderdikten sonra uygulamayı tekrar açıp bakmayı düşünmez.
     */
    protected function afterSave(): void
    {
        $record = $this->getRecord();

        if (! $record->wasChanged('reply')) {
            return;
        }

        $yanit = trim((string) $record->reply);
        if ($yanit === '') {
            return;
        }

        $record->respond($yanit, $record->status === 'YENI' ? 'YANITLANDI' : $record->status);
    }
}
