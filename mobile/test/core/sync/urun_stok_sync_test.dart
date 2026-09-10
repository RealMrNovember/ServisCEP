import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/core/database/app_database.dart';
import 'package:serviscep/core/network/sync_api_client.dart';
import 'package:serviscep/core/sync/sync_service.dart';
import 'package:serviscep/features/stock/data/products_repository.dart';

import '../../support/fake_sync_api_client.dart';
import '../../support/fake_token_store.dart';
import '../../support/in_memory_database.dart';

const _companyId = 'company-1';

/// Ürün ve stok verisinin sunucuya ULAŞTIĞININ kanıtı.
///
/// NEDEN VAR: `products` ve `stock_movements` tabloları baştan beri vardı
/// ama hiçbir API ucu yoktu ve mobil taraf kuyruğa hiçbir şey yazmıyordu.
/// Kullanıcının ürün kataloğu ve stok geçmişi YALNIZCA telefonunda
/// duruyordu; telefon kaybolduğunda geri getirilemiyordu — üstelik
/// uygulama `allowBackup="false"` ile geliyor ve gerekçesi "zaten her şey
/// sunucuyla eşitleniyor" diye yazılmıştı.
///
/// Buradaki testler bunun bir daha sessizce kopmamasını sağlıyor: kuyruk
/// satırı yazılmazsa ya da gönderim yolu kaldırılırsa CI patlar.
void main() {
  late AppDatabase db;
  late FakeSyncApiClient api;
  late ProductsRepository repo;

  setUp(() async {
    db = createInMemoryDatabase();
    api = FakeSyncApiClient();
    repo = ProductsRepository(db);
    await db
        .into(db.companies)
        .insert(CompaniesCompanion.insert(id: _companyId, name: 'Test Co'));
  });

  tearDown(() => db.close());

  SyncService servis() =>
      SyncService(db, api, FakeTokenStore(initialToken: 'test-token'));

  Future<Product> urunOlustur({int stok = 0}) => repo.create(
    companyId: _companyId,
    name: 'Kombi Devirdaim Pompası',
    salePriceMinor: 240000,
    currentStock: stok,
  );

  test('yeni ürün kuyruğa yazılır ve sunucuya gönderilir', () async {
    final urun = await urunOlustur(stok: 5);

    final kuyruk = await db.select(db.syncOperations).get();
    expect(
      kuyruk,
      hasLength(1),
      reason: 'ürün kuyruğa hiç girmiyorsa sunucuya asla ulaşmaz',
    );
    expect(kuyruk.single.entityType, 'product');
    expect(kuyruk.single.entityId, urun.id);

    await servis().runOnce(_companyId);

    expect(api.createProductCalls, hasLength(1));
    expect(api.createProductCalls.single['id'], urun.id);
    expect(api.createProductCalls.single['sale_price_minor'], 240000);
    // Açılış stoğu da gitmeli, yoksa sunucudaki adet sıfır kalır.
    expect(api.createProductCalls.single['current_stock'], 5);
  });

  test('stok hareketi ADET olarak değil HAREKET olarak gönderilir', () async {
    final urun = await urunOlustur(stok: 10);
    await servis().runOnce(_companyId);
    api.createProductCalls.clear();

    await repo.adjustStock(
      product: (await repo.byId(urun.id))!,
      delta: -3,
      referenceType: 'job',
      note: 'Serviste kullanıldı',
    );

    await servis().runOnce(_companyId);

    expect(api.createStockMovementCalls, hasLength(1));
    final hareket = api.createStockMovementCalls.single;
    expect(hareket['product_id'], urun.id);
    expect(hareket['type'], 'OUT');
    expect(hareket['quantity'], 3);

    // Ürün güncellemesi stok adedini GÖNDERMEMELİ: adet sunucuda hareket
    // defterinden türetiliyor. Sütunu doğrudan yazmak, çevrimdışı iki
    // cihazın stok düşüşünden birini yok sayardı.
    for (final (_, payload) in api.updateProductCalls) {
      expect(payload.containsKey('current_stock'), isFalse);
    }
  });

  test('ürün düzenlemesi kuyruğa girer, stok adedi gönderilmez', () async {
    final urun = await urunOlustur(stok: 4);
    await servis().runOnce(_companyId);

    await repo.update(urun.copyWith(name: 'Yeni Ad', salePriceMinor: 300000));
    await servis().runOnce(_companyId);

    expect(api.updateProductCalls, hasLength(1));
    final (id, payload) = api.updateProductCalls.single;
    expect(id, urun.id);
    expect(payload['name'], 'Yeni Ad');
    expect(payload['sale_price_minor'], 300000);
    expect(payload.containsKey('current_stock'), isFalse);
  });

  test('silinen ürün sunucuya da bildirilir', () async {
    final urun = await urunOlustur();
    await servis().runOnce(_companyId);

    await repo.delete(urun);
    await servis().runOnce(_companyId);

    expect(api.deleteProductCalls, contains(urun.id));
  });

  test('sunucudaki ürün cihaza iner', () async {
    api.productsToPull = [
      RemoteRecord(
        id: 'urun-uzak',
        version: 1,
        raw: const {
          'id': 'urun-uzak',
          'name': 'Ofisten girilen ürün',
          'unit': 'adet',
          'purchase_price_minor': 1000,
          'sale_price_minor': 2000,
          'current_stock': 7,
          'min_stock': 1,
          'source': 'MANUAL',
          'deleted_at': null,
        },
      ),
    ];

    await servis().runOnce(_companyId);

    final urun = await repo.byId('urun-uzak');
    expect(urun, isNotNull);
    expect(urun!.name, 'Ofisten girilen ürün');
    // Adet sunucunun hesabı: defterden türetiliyor.
    expect(urun.currentStock, 7);
  });

  test('ofiste silinen ürün cihazda da kaybolur', () async {
    api.productsToPull = [
      RemoteRecord(
        id: 'urun-silinmis',
        version: 1,
        raw: const {
          'id': 'urun-silinmis',
          'name': 'Kaldırılan ürün',
          'unit': 'adet',
          'current_stock': 0,
          'min_stock': 0,
          'deleted_at': '2026-09-10T10:00:00.000Z',
        },
      ),
    ];

    await servis().runOnce(_companyId);

    // Mezar taşı olmadan cihaz, ürünün silindiğini asla öğrenemez.
    final gorunenler = await repo.watchAll(_companyId).first;
    expect(gorunenler.where((u) => u.id == 'urun-silinmis'), isEmpty);
  });

  test('gönderilmemiş yerel değişiklik pull ile EZİLMEZ', () async {
    final urun = await urunOlustur();
    await servis().runOnce(_companyId);

    await repo.update(urun.copyWith(name: 'Cihazda değiştirdim'));

    api.productsToPull = [
      RemoteRecord(
        id: urun.id,
        version: 1,
        raw: {
          'id': urun.id,
          'name': 'Sunucudaki eski ad',
          'unit': 'adet',
          'current_stock': 0,
          'min_stock': 0,
          'deleted_at': null,
        },
      ),
    ];

    // Gönderim başarısız olsun ki satır kuyrukta kalsın.
    api.failNextUpdateProduct = true;
    await servis().runOnce(_companyId);

    expect((await repo.byId(urun.id))!.name, 'Cihazda değiştirdim');
  });

  test('ürünü olmayan stok hareketi turu öldürmez, atlanır', () async {
    // Yabancı anahtar: ürün yerelde yoksa satır yazılamaz. Bir sonraki
    // turda ürün gelince hareket de eklenir.
    api.stockMovementsToPull = [
      RemoteRecord(
        id: 'hareket-1',
        version: 1,
        raw: const {
          'id': 'hareket-1',
          'product_id': 'henuz-inmemis-urun',
          'type': 'IN',
          'quantity': 2,
          'reference_type': 'purchase',
          'created_at': '2026-09-10T10:00:00.000Z',
        },
      ),
    ];

    await expectLater(servis().runOnce(_companyId), completion(isTrue));
    expect(await db.select(db.stockMovements).get(), isEmpty);
  });
}
