import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/data/session_controller.dart';

/// Stok durumu — bkz. docs/16 § Stok Durumu Badge'i.
///
/// ⚠️ Bu değer yalnızca uygulama içi arayüzde kullanılır, PDF/belge
/// çıktılarına ASLA yansıtılmaz.
enum StockStatus { inStock, low, outOfStock }

extension StockStatusX on Product {
  StockStatus get stockStatus {
    if (currentStock <= 0) return StockStatus.outOfStock;
    if (currentStock <= minStock) return StockStatus.low;
    return StockStatus.inStock;
  }
}

class ProductsRepository {
  ProductsRepository(this._db);
  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<Product>> watchAll(String companyId) {
    return (_db.select(_db.products)
          ..where((p) => p.companyId.equals(companyId) & p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch();
  }

  Future<Product?> findByBarcode(String companyId, String barcode) {
    return (_db.select(_db.products)..where(
          (p) => p.companyId.equals(companyId) & p.barcode.equals(barcode) & p.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<Product?> byId(String id) {
    return (_db.select(_db.products)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Future<Product> create({
    required String companyId,
    required String name,
    String? barcode,
    String? sku,
    String? brand,
    String? model,
    String? category,
    String unit = 'adet',
    int purchasePriceMinor = 0,
    int salePriceMinor = 0,
    int currentStock = 0,
    int minStock = 0,
    String source = 'MANUAL',
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.products).insert(
      ProductsCompanion.insert(
        id: id,
        companyId: companyId,
        name: name,
        barcode: Value(barcode),
        sku: Value(sku),
        brand: Value(brand),
        model: Value(model),
        category: Value(category),
        unit: Value(unit),
        purchasePriceMinor: Value(purchasePriceMinor),
        salePriceMinor: Value(salePriceMinor),
        currentStock: Value(currentStock),
        minStock: Value(minStock),
        source: Value(source),
      ),
    );
    return (await byId(id))!;
  }

  Future<void> update(Product product) {
    return _db.update(_db.products).replace(product);
  }

  /// Stok hareketi + mevcut miktar güncellemesi — tek transaction (bkz.
  /// docs/07 § Transaction Kuralı).
  Future<void> adjustStock({
    required Product product,
    required int delta,
    required String referenceType,
    String? referenceId,
    String? note,
  }) async {
    await _db.transaction(() async {
      final newStock = product.currentStock + delta;
      await _db
          .update(_db.products)
          .replace(product.copyWith(currentStock: newStock));

      await _db.into(_db.stockMovements).insert(
        StockMovementsCompanion.insert(
          id: _uuid.v4(),
          companyId: product.companyId,
          productId: product.id,
          type: delta >= 0 ? 'IN' : 'OUT',
          quantity: delta.abs(),
          referenceType: referenceType,
          referenceId: Value(referenceId),
          note: Value(note),
        ),
      );
    });
  }

  /// Global barkod veri kaynağı sorgusu — bkz. docs/16 § Barkod Okuma Akışı.
  ///
  /// NOT: Sağlayıcı implementasyon aşamasında seçilecektir (dış API
  /// bağımlılığı, maliyet/anahtar gerektirir). Şimdilik null döner —
  /// arayan taraf (barkod tarama akışı) bunu "bulunamadı" olarak ele alıp
  /// manuel forma yönlendirir. Bu, sessizce yanlış davranmaktan iyidir:
  /// özellik dürüstçe "henüz yok" der.
  Future<GlobalProductLookupResult?> lookupGlobalBarcode(String barcode) async {
    return null;
  }
}

class GlobalProductLookupResult {
  const GlobalProductLookupResult({required this.name, this.brand, this.category});
  final String name;
  final String? brand;
  final String? category;
}

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(ref.watch(databaseProvider));
});

final productsListProvider = StreamProvider<List<Product>>((ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  if (session == null) return const Stream.empty();
  return ref.watch(productsRepositoryProvider).watchAll(session.companyId);
});
