<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\AcceptsClientGeneratedId;
use App\Http\Controllers\Controller;
use App\Http\Requests\Product\StoreProductRequest;
use App\Http\Requests\Product\UpdateProductRequest;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use App\Models\StockMovement;
use App\Services\AuditLogService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

/**
 * Ürün kataloğu — mobil senkronun sunucu ucu.
 *
 * NEDEN SONRADAN YAZILDI: `products` ve `stock_movements` tabloları
 * baştan beri vardı ama HİÇBİR API ucu yoktu. Mobil taraf da kuyruğa
 * hiçbir şey yazmıyordu; yani kullanıcının ürün kataloğu ve stok geçmişi
 * YALNIZCA telefonda duruyordu. Telefon kaybolduğunda ya da uygulama
 * silindiğinde katalog geri getirilemiyordu.
 *
 * Bu, uygulamanın kendi vaadiyle de çelişiyordu: AndroidManifest'te
 * `allowBackup="false"` tercih edilmişti ve gerekçesi "tüm veri sunucuyla
 * eşitleniyor, cihazdaki veritabanı yalnızca bir önbellek" diye
 * yazılmıştı. Ürünler için bu doğru değildi.
 */
class ProductController extends Controller
{
    use AcceptsClientGeneratedId;

    public function __construct(
        private readonly AuditLogService $auditLogService,
    ) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        Gate::authorize('viewAny', Product::class);

        $products = Product::query()
            // Silinenler de dönüyor: mezar taşı olmadan cihaz, ofiste
            // silinen ürünün silindiğini asla öğrenemez.
            ->withTrashed()
            ->when($request->filled('q'), function ($query) use ($request) {
                $term = '%'.$request->input('q').'%';
                $query->where(function ($query) use ($term) {
                    $query->where('name', 'like', $term)
                        ->orWhere('barcode', 'like', $term)
                        ->orWhere('sku', 'like', $term);
                });
            })
            ->latest('created_at')
            ->paginate($this->sayfaBoyutu($request));

        return ProductResource::collection($products);
    }

    public function store(StoreProductRequest $request): JsonResponse
    {
        Gate::authorize('create', Product::class);

        // Aynı kaydın ikinci kez gönderilmesi (yeniden deneme) yeni ürün
        // oluşturmaz. Product'ta BelongsToCompany global scope'u var,
        // dolayısıyla arama şirkete kapsanmış durumda.
        if ($existing = $this->findExistingByClientId(Product::class, $request->input('id'))) {
            return (new ProductResource($existing))->response()->setStatusCode(200);
        }

        $data = $request->validated();
        $acilisStogu = (int) ($data['current_stock'] ?? 0);
        unset($data['current_stock']);

        $product = DB::transaction(function () use ($data, $acilisStogu, $request): Product {
            $product = Product::create($data + ['current_stock' => 0]);

            // Açılış stoğu bir HAREKET olarak yazılıyor; adet böylece her
            // zaman defterden türetilebilir kalıyor.
            if ($acilisStogu !== 0) {
                StockMovement::create([
                    'company_id' => $product->company_id,
                    'product_id' => $product->id,
                    'type' => $acilisStogu > 0 ? 'IN' : 'OUT',
                    'quantity' => abs($acilisStogu),
                    'reference_type' => 'opening_balance',
                    'note' => 'Açılış stoğu',
                ]);
            }

            $product->update(['current_stock' => self::stokHesapla($product)]);

            return $product;
        });

        $product->refresh();

        $this->auditLogService->record(
            $request->user(), 'product.created', 'product', $product->id,
            "Ürün oluşturuldu: {$product->name}"
        );

        return (new ProductResource($product))->response()->setStatusCode(201);
    }

    public function show(Product $product): ProductResource
    {
        Gate::authorize('view', $product);

        return new ProductResource($product);
    }

    public function update(UpdateProductRequest $request, Product $product): JsonResponse
    {
        Gate::authorize('update', $product);

        // Sürüm tabanlı çakışma çözümü YOK — bilinçli.
        //
        // Katalog kaydı pratikte tek kişi tarafından, seyrek düzenleniyor
        // ve çakışan alan (ad, fiyat) için son yazan kazanmak kabul
        // edilebilir. Asıl çakışma riski taşıyan STOK ADEDİ ise bu uçtan
        // hiç yazılmıyor: hareket defterinden türetiliyor.
        $product->update($request->validated());

        $this->auditLogService->record(
            $request->user(), 'product.updated', 'product', $product->id,
            "Ürün güncellendi: {$product->name}"
        );

        return (new ProductResource($product->refresh()))->response();
    }

    public function destroy(Request $request, Product $product): Response
    {
        Gate::authorize('delete', $product);

        $ad = $product->name;
        // Soft delete: stok hareketleri ürüne restrictOnDelete ile bağlı,
        // ayrıca geçmiş belgelerde geçen bir ürün yok olmamalı.
        $product->delete();

        $this->auditLogService->record(
            $request->user(), 'product.deleted', 'product', $product->id,
            "Ürün silindi: {$ad}"
        );

        return response()->noContent();
    }

    /** Ürünün stok adedi — hareket defterinden. */
    public static function stokHesapla(Product $product): int
    {
        $hareketler = StockMovement::query()
            ->where('product_id', $product->id)
            ->selectRaw("COALESCE(SUM(CASE WHEN type = 'IN' THEN quantity ELSE -quantity END), 0) AS toplam")
            ->value('toplam');

        return (int) $hareketler;
    }

    /**
     * Sayfa boyutu — sınırsız değil.
     *
     * `?per_page=-1` Laravel'de limit uygulanmamasına yol açıyor, yani
     * tüm tablo tek yanıtta dönüyordu; büyük değerler de belleği
     * tüketiyor.
     */
    private function sayfaBoyutu(Request $request): int
    {
        return max(1, min(200, (int) $request->input('per_page', 50)));
    }
}
