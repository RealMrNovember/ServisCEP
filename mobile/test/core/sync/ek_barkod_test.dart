import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/core/database/app_database.dart';
import 'package:serviscep/core/network/sync_api_client.dart';
import 'package:serviscep/core/sync/sync_service.dart';
import 'package:serviscep/features/stock/data/products_repository.dart';

import '../../support/fake_sync_api_client.dart';
import '../../support/fake_token_store.dart';
import '../../support/in_memory_database.dart';

const _companyId = 'company-1';

/// Bir ürüne birden fazla barkod bağlama.
///
/// NEDEN VAR: müşteri "barkod okutuyorum ama ürün gelmiyor" dedi.
/// Şikâyete konu kamera kutusunda perakende barkodu değil SERİ NUMARASI
/// vardı (S/N:UNW0101024101227 — geçerli EAN-13 bile değil) ve seri her
/// kutuda farklı. Kullanıcı ilk kamerayı elle tanımlasa bile aynı
/// modelin ikinci kutusu başka kod okutuyor ve hiçbir zaman
/// eşleşmiyordu. Küresel barkod veritabanı bu işi ÇÖZMEZDİ; çözüm kodu
/// ürüne bağlayabilmek.
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

  Future<Product> kamera() => repo.create(
    companyId: _companyId,
    name: 'UNIYWELL UNW-K557H-RN8C',
    barcode: 'UNW0101024101227',
  );

  test('ürünün kendi barkodu bulunur', () async {
    final urun = await kamera();

    expect(
      (await repo.barkodlaBul(_companyId, 'UNW0101024101227'))?.id,
      urun.id,
    );
  });

  test('bağlanan ikinci seri de AYNI ürünü bulur', () async {
    // Asıl senaryo: ikinci kutu farklı seri okutuyor.
    final urun = await kamera();
    await repo.barkodBagla(urun: urun, barcode: 'UNW0101024101228');

    final bulunan = await repo.barkodlaBul(_companyId, 'UNW0101024101228');
    expect(bulunan?.id, urun.id);
    expect(bulunan?.name, 'UNIYWELL UNW-K557H-RN8C');
  });

  test('tanınmayan kod null döner', () async {
    await kamera();

    expect(await repo.barkodlaBul(_companyId, 'BILINMEYEN-KOD'), isNull);
  });

  test('bağlanan kod sunucuya gönderilir', () async {
    final urun = await kamera();
    await repo.barkodBagla(urun: urun, barcode: 'UNW0101024101228');

    await servis().runOnce(_companyId);

    expect(api.createProductBarcodeCalls, hasLength(1));
    final gonderilen = api.createProductBarcodeCalls.single;
    expect(gonderilen['product_id'], urun.id);
    expect(gonderilen['barcode'], 'UNW0101024101228');
  });

  test('kaldırılan bağ sunucuya bildirilir', () async {
    final urun = await kamera();
    await repo.barkodBagla(urun: urun, barcode: 'UNW0101024101228');
    await servis().runOnce(_companyId);

    final bag = (await repo.barkodlariIzle(urun.id).first).single;
    await repo.barkodKaldir(bag);
    await servis().runOnce(_companyId);

    expect(api.deleteProductBarcodeCalls, contains(bag.id));
    expect(await repo.barkodlaBul(_companyId, 'UNW0101024101228'), isNull);
  });

  test('ofisten bağlanan kod cihaza iner', () async {
    final urun = await kamera();

    api.productBarcodesToPull = [
      RemoteRecord(
        id: 'bag-1',
        version: 1,
        raw: {
          'id': 'bag-1',
          'product_id': urun.id,
          'barcode': 'OFISTEN-BAGLANDI',
        },
      ),
    ];

    await servis().runOnce(_companyId);

    expect(
      (await repo.barkodlaBul(_companyId, 'OFISTEN-BAGLANDI'))?.id,
      urun.id,
    );
  });

  test('ofiste kaldırılan bağ cihazda da kalkar', () async {
    // Kalkmazsa tarama artık geçerli olmayan bir ürünü açar.
    final urun = await kamera();

    api.productBarcodesToPull = [
      RemoteRecord(
        id: 'bag-1',
        version: 1,
        raw: {'id': 'bag-1', 'product_id': urun.id, 'barcode': 'GECICI'},
      ),
    ];
    await servis().runOnce(_companyId);
    expect(await repo.barkodlaBul(_companyId, 'GECICI'), isNotNull);

    api.productBarcodesToPull = [];
    await servis().runOnce(_companyId);

    expect(await repo.barkodlaBul(_companyId, 'GECICI'), isNull);
  });

  test('gönderilmemiş yerel bağ pull ile SİLİNMEZ', () async {
    // Çevrimdışı bağlanan kod, sunucu listesinde yok diye silinemez;
    // yoksa kullanıcının az önce yaptığı iş kaybolur.
    final urun = await kamera();
    await repo.barkodBagla(urun: urun, barcode: 'CEVRIMDISI-BAG');

    api.productBarcodesToPull = [];
    // Gönderim başarısız olsun ki satır kuyrukta kalsın.
    api.failNextCreateProductBarcode = true;
    await servis().runOnce(_companyId);

    expect(
      (await repo.barkodlaBul(_companyId, 'CEVRIMDISI-BAG'))?.id,
      urun.id,
    );
  });

  test('ürünü olmayan bağ turu öldürmez, atlanır', () async {
    api.productBarcodesToPull = [
      RemoteRecord(
        id: 'bag-1',
        version: 1,
        raw: const {
          'id': 'bag-1',
          'product_id': 'henuz-inmemis-urun',
          'barcode': 'KOD',
        },
      ),
    ];

    await expectLater(servis().runOnce(_companyId), completion(isTrue));
    expect(await db.select(db.productBarcodes).get(), isEmpty);
  });
}
