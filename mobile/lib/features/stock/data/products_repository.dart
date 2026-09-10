import 'dart:convert';

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
          (p) =>
              p.companyId.equals(companyId) &
              p.barcode.equals(barcode) &
              p.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<Product?> byId(String id) {
    return (_db.select(
      _db.products,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
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
    // Yazma ve kuyruk satırı AYNI transaction'da: bir kayıt asla kuyruk
    // satırı olmadan yerelde kalmaz.
    await _db.transaction(() async {
      await _db
          .into(_db.products)
          .insert(
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

      await _enqueue(
        entityId: id,
        operation: 'CREATE',
        payload: {
          'id': id,
          'name': name,
          'barcode': barcode,
          'sku': sku,
          'brand': brand,
          'model': model,
          'category': category,
          'unit': unit,
          'purchase_price_minor': purchasePriceMinor,
          'sale_price_minor': salePriceMinor,
          // Açılış stoğu; sunucu bunu bir hareket olarak yazıyor.
          'current_stock': currentStock,
          'min_stock': minStock,
          'source': source,
        },
      );
    });
    return (await byId(id))!;
  }

  Future<void> update(Product product) async {
    await _db.transaction(() async {
      await _db.update(_db.products).replace(product);

      // current_stock BİLEREK gönderilmiyor: adet sunucuda hareket
      // defterinden türetiliyor. Buradan yazmak, çevrimdışı iki cihazın
      // stok düşüşünden birini yok sayardı.
      await _enqueue(
        entityId: product.id,
        operation: 'UPDATE',
        payload: {
          'name': product.name,
          'barcode': product.barcode,
          'sku': product.sku,
          'brand': product.brand,
          'model': product.model,
          'category': product.category,
          'unit': product.unit,
          'purchase_price_minor': product.purchasePriceMinor,
          'sale_price_minor': product.salePriceMinor,
          'min_stock': product.minStock,
        },
      );
    });
  }

  /// Ürünü siler (yerelde mezar taşı, sunucuda soft delete).
  Future<void> delete(Product product) async {
    await _db.transaction(() async {
      await (_db.update(
        _db.products,
      )..where((p) => p.id.equals(product.id))).write(
        ProductsCompanion(deletedAt: Value(DateTime.now())),
      );
      await _enqueue(
        entityId: product.id,
        operation: 'DELETE',
        payload: const {},
      );
    });
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

      final hareketId = _uuid.v4();
      await _db
          .into(_db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              id: hareketId,
              companyId: product.companyId,
              productId: product.id,
              type: delta >= 0 ? 'IN' : 'OUT',
              quantity: delta.abs(),
              referenceType: referenceType,
              referenceId: Value(referenceId),
              note: Value(note),
            ),
          );

      // Sunucuya HAREKET gönderiliyor, adet değil. Hareket defteri
      // değişmez ve toplanabilir; iki cihaz çevrimdışı stok düşerse
      // ikisi de sayılır.
      await _enqueue(
        entityType: 'stock_movement',
        entityId: hareketId,
        operation: 'CREATE',
        payload: {
          'id': hareketId,
          'product_id': product.id,
          'type': delta >= 0 ? 'IN' : 'OUT',
          'quantity': delta.abs(),
          'reference_type': referenceType,
          'reference_id': referenceId,
          'note': note,
        },
      );
    });
  }

  Future<void> _enqueue({
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    String entityType = 'product',
  }) {
    return _db
        .into(_db.syncOperations)
        .insert(
          SyncOperationsCompanion.insert(
            id: _uuid.v4(),
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payload: jsonEncode(payload),
          ),
        );
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
  const GlobalProductLookupResult({
    required this.name,
    this.brand,
    this.category,
  });
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
