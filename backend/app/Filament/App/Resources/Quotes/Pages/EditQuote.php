<?php

namespace App\Filament\App\Resources\Quotes\Pages;

use App\Filament\App\Resources\Quotes\QuoteResource;
use App\Support\DocumentTotal;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

class EditQuote extends EditRecord
{
    protected static string $resource = QuoteResource::class;

    protected function getHeaderActions(): array
    {
        return [
            DeleteAction::make(),
        ];
    }

    protected function mutateFormDataBeforeFill(array $data): array
    {
        $data['items'] = $this->getRecord()->items()->get()->toArray();

        return $data;
    }

    protected function handleRecordUpdate(Model $record, array $data): Model
    {
        $items = $data['items'] ?? [];
        unset($data['items']);

        $data['total_minor'] = DocumentTotal::forItems($items, $data['vat_mode'] ?? 'EXCLUDED');

        DB::transaction(function () use ($record, $data, $items) {
            $record->update($data);
            $record->items()->delete();

            foreach ($items as $item) {
                $record->items()->create($item);
            }
        });

        return $record;
    }
}
