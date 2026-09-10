<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\AcceptsClientGeneratedId;
use App\Http\Controllers\Controller;
use App\Http\Requests\Product\StoreProductBarcodeRequest;
use App\Http\Resources\ProductBarcodeResource;
use App\Models\Product;
use App\Models\ProductBarcode;
use App\Support\RolePermissions;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Gate;

/**
 * Bir ürüne bağlanan ek barkodlar.
 *
 * NEDEN VAR: `products.barcode` tek kod tutuyor. Güvenlik kamerası gibi
 * ürünlerin kutusunda perakende barkodu yerine SERİ NUMARASI oluyor ve
 * seri her kutuda farklı; aynı modelin ikinci kutusu hiçbir zaman
 * eşleşmiyordu. Kurulumcu yeni kutuyu okutup mevcut ürüne bağlayabilsin
 * diye bu uç yazıldı.
 */
class ProductBarcodeController extends Controller
{
    use AcceptsClientGeneratedId;

    public function index(Request $request): AnonymousResourceCollection
    {
        Gate::authorize('viewAny', Product::class);

        $kayitlar = ProductBarcode::query()
            ->when(
                $request->filled('product_id'),
                fn ($query) => $query->where('product_id', $request->input('product_id'))
            )
            ->latest('created_at')
            ->paginate(max(1, min(200, (int) $request->input('per_page', 200))));

        return ProductBarcodeResource::collection($kayitlar);
    }

    public function store(StoreProductBarcodeRequest $request): JsonResponse
    {
        // Yetki doğrudan sorulur: 'update' politikası bir Product ÖRNEĞİ
        // bekliyor, burada yetki katalog geneli.
        abort_unless(
            $request->user()->hasPermission(RolePermissions::DOCUMENTS_MANAGE),
            403,
            'Ürün kataloğunu değiştirme yetkin yok.',
        );

        // Yeniden gönderim mükerrer satır yazmamalı.
        if ($existing = $this->findExistingByClientId(ProductBarcode::class, $request->input('id'))) {
            return (new ProductBarcodeResource($existing))->response()->setStatusCode(200);
        }

        $kayit = ProductBarcode::create($request->validated());

        return (new ProductBarcodeResource($kayit->refresh()))->response()->setStatusCode(201);
    }

    public function destroy(Request $request, ProductBarcode $productBarcode): Response
    {
        abort_unless(
            $request->user()->hasPermission(RolePermissions::DOCUMENTS_MANAGE),
            403,
            'Ürün kataloğunu değiştirme yetkin yok.',
        );

        $productBarcode->delete();

        return response()->noContent();
    }
}
