<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Services\GlobalBarcodeLookup;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

/**
 * Taranan barkodu açık ürün veritabanlarında arar.
 *
 * Uygulama, kod kendi kataloğunda bulunamadığında buraya soruyor ve
 * dönen bilgiyi yeni ürün formuna önceden yazıyor.
 *
 * Bulunamaması NORMAL: bu veritabanları ağırlıklı olarak market
 * ürünlerini kapsıyor. Elektrik malzemesi ve güvenlik kamerası gibi
 * ürünlerin kutusunda çoğu zaman perakende barkodu yerine üretici seri
 * numarası oluyor ve seriler hiçbir ürün veritabanında yer almıyor.
 */
class BarcodeLookupController extends Controller
{
    public function __invoke(Request $request, GlobalBarcodeLookup $sorgu): JsonResponse
    {
        Gate::authorize('viewAny', Product::class);

        $dogrulanan = $request->validate([
            'barcode' => ['required', 'string', 'max:64'],
        ]);

        $sonuc = $sorgu->ara($dogrulanan['barcode']);

        return response()->json([
            'data' => [
                'barcode' => $dogrulanan['barcode'],
                'found' => $sonuc['found'],
                'name' => $sonuc['name'],
                'brand' => $sonuc['brand'],
                'category' => $sonuc['category'],
                'source' => $sonuc['source'],
            ],
        ]);
    }
}
