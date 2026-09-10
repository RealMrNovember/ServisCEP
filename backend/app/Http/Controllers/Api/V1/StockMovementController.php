<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\AcceptsClientGeneratedId;
use App\Http\Controllers\Controller;
use App\Http\Requests\Stock\StoreStockMovementRequest;
use App\Http\Resources\StockMovementResource;
use App\Models\Product;
use App\Models\StockMovement;
use App\Support\RolePermissions;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

/**
 * Stok hareketleri — değişmez (immutable) defter, cari hesapla aynı
 * felsefe.
 *
 * Neden defter: iki teknisyen çevrimdışıyken aynı üründen parça
 * kullanırsa, `current_stock` sütununu doğrudan yazmak son yazanın
 * diğerini ezmesi demek olurdu. Hareket olarak gelince ikisi de sayılır
 * ve adet her zaman yeniden hesaplanabilir. Bu yüzden güncelleme/silme
 * ucu YOK: yanlış bir hareket, ters yönde ikinci bir hareketle
 * düzeltilir.
 */
class StockMovementController extends Controller
{
    use AcceptsClientGeneratedId;

    public function index(Request $request): AnonymousResourceCollection
    {
        Gate::authorize('viewAny', Product::class);

        $hareketler = StockMovement::query()
            ->when(
                $request->filled('product_id'),
                fn ($query) => $query->where('product_id', $request->input('product_id'))
            )
            ->latest('created_at')
            ->paginate(max(1, min(200, (int) $request->input('per_page', 100))));

        return StockMovementResource::collection($hareketler);
    }

    public function store(StoreStockMovementRequest $request): JsonResponse
    {
        // Yetki DOGRUDAN sorulur: 'update' politikasi bir Product
        // ORNEGI bekliyor, burada henuz ortada tek bir urun yok
        // (hareket bir urune yaziliyor ama yetki katalog geneli).
        abort_unless(
            $request->user()->hasPermission(RolePermissions::DOCUMENTS_MANAGE),
            403,
            'Stok hareketi yazma yetkin yok.',
        );

        // Yeniden gönderim aynı hareketi ikinci kez YAZMAMALI: stok
        // adedi defterden türetildiği için mükerrer satır doğrudan
        // yanlış adet demek.
        if ($existing = $this->findExistingByClientId(StockMovement::class, $request->input('id'))) {
            return (new StockMovementResource($existing))->response()->setStatusCode(200);
        }

        $hareket = DB::transaction(function () use ($request): StockMovement {
            $hareket = StockMovement::create($request->validated());

            $product = Product::withTrashed()->findOrFail($hareket->product_id);
            $product->update(['current_stock' => ProductController::stokHesapla($product)]);

            return $hareket;
        });

        return (new StockMovementResource($hareket->refresh()))->response()->setStatusCode(201);
    }
}
