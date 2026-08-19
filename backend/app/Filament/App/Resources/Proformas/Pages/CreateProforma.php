<?php

namespace App\Filament\App\Resources\Proformas\Pages;

use App\Filament\App\Resources\Concerns\CalculatesDocumentTotal;
use App\Filament\App\Resources\Proformas\ProformaResource;
use App\Models\Proforma;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

class CreateProforma extends CreateRecord
{
    use CalculatesDocumentTotal;

    protected static string $resource = ProformaResource::class;

    protected function handleRecordCreation(array $data): Model
    {
        $items = $data['items'] ?? [];
        unset($data['items']);

        $data['code'] = 'PRO-'.str_pad((string) (Proforma::count() + 1), 4, '0', STR_PAD_LEFT);
        $data['total_minor'] = $this->calculateItemsTotal($items);

        return DB::transaction(function () use ($data, $items) {
            $proforma = Proforma::create($data);

            foreach ($items as $item) {
                $proforma->items()->create($item);
            }

            return $proforma;
        });
    }
}
