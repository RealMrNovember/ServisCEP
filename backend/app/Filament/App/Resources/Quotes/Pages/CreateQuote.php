<?php

namespace App\Filament\App\Resources\Quotes\Pages;

use App\Filament\App\Resources\Quotes\QuoteResource;
use App\Models\Quote;
use App\Support\DocumentTotal;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

class CreateQuote extends CreateRecord
{
    protected static string $resource = QuoteResource::class;

    protected function handleRecordCreation(array $data): Model
    {
        $items = $data['items'] ?? [];
        unset($data['items']);

        $data['code'] = 'TEK-'.str_pad((string) (Quote::count() + 1), 4, '0', STR_PAD_LEFT);
        $data['total_minor'] = DocumentTotal::forItems($items, $data['vat_mode'] ?? 'EXCLUDED');

        return DB::transaction(function () use ($data, $items) {
            $quote = Quote::create($data);

            foreach ($items as $item) {
                $quote->items()->create($item);
            }

            return $quote;
        });
    }
}
