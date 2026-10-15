<?php

declare(strict_types=1);

namespace App\Http\Requests\Quote;

use Illuminate\Foundation\Http\FormRequest;

class UpdateQuoteRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'intro_text' => ['sometimes', 'nullable', 'string', 'max:2000'],
            'payment_terms' => ['sometimes', 'nullable', 'string', 'max:255'],
            'delivery_time' => ['sometimes', 'nullable', 'string', 'max:255'],
            'warranty_terms' => ['sometimes', 'nullable', 'string', 'max:255'],
            'currency' => ['sometimes', 'string', 'in:TRY,USD,EUR'],
            'vat_mode' => ['sometimes', 'string', 'in:EXCLUDED,INCLUDED'],
            'vat_rate' => ['sometimes', 'integer', 'min:0', 'max:100'],
            'valid_until' => ['sometimes', 'nullable', 'date'],
            'base_version' => ['required', 'integer', 'min:1'],

            // İstemcinin GERÇEKTEN değiştirdiği alanlar. Yük kaydın
            // tamamını taşıdığı için bu bilgi yükten çıkarılamıyor; onsuz
            // her sürüm uyuşmazlığı elle çözülmesi gereken bir çakışma
            // sayılırdı (bkz. DetectsSyncConflicts).
            //
            // `sometimes`: eski uygulama sürümleri bunu göndermiyor ve
            // göndermedikleri sürece eski davranışı görüyorlar.
            'changed_fields' => ['sometimes', 'array'],
            'changed_fields.*' => ['string', 'max:64'],
            'status' => ['sometimes', 'string', 'in:TASLAK,GONDERILDI,BEKLEMEDE,KABUL_EDILDI,REDDEDILDI,SURESI_DOLDU'],
            'notes' => ['sometimes', 'nullable', 'string'],

            // Kalemler. Belge olustuktan sonra en cok duzeltilen sey bir
            // kalemin adedi ya da fiyati; `store` bunlari bastan beri
            // kabul ediyordu, `update` etmiyordu ve bu yuzden olusmus bir
            // belgenin tutari API uzerinden hic degistirilemiyordu.
            //
            // `sometimes`: yalnizca durum degistiren istek (teklifte
            // "Gonderildi") kalem gondermez ve gondermedigi surece mevcut
            // kalemlere dokunulmaz.
            //
            // Gelirse TAMAMI gelir: liste kaydin yeni hali olarak
            // uygulanir, kismi guncelleme yoktur. Eksik gonderilen bir
            // kalem silinmis sayilir.
            'items' => ['sometimes', 'array', 'min:1'],
            'items.*.id' => ['sometimes', 'uuid'],
            'items.*.description' => ['required', 'string', 'max:255'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.unit' => ['nullable', 'string', 'max:20'],
            'items.*.unit_price_minor' => ['required', 'integer', 'min:0'],
            'items.*.tax_rate' => ['nullable', 'integer', 'min:0', 'max:100'],
            'items.*.discount_minor' => ['nullable', 'integer', 'min:0'],
            'items.*.discount_rate' => ['nullable', 'integer', 'min:0', 'max:100'],

            // Duzenlemenin GERCEKTE yapildigi an. Uygulama offline
            // duzenleyip gunler sonra senkron olabiliyor; sunucu saatini
            // yazmak o ani kaybettirirdi.
            'edited_at' => ['sometimes', 'nullable', 'date'],
        ];
    }
}
