import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/core/database/app_database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v9.dart' as v9;
import '../../generated_migrations/schema_v10.dart' as v10;

/// Şema göçleri.
///
/// NEDEN VAR: sekiz göç adımı (v1→v9) yazılmıştı ve HİÇBİRİ test
/// edilmiyordu. Göç, uygulamadaki tek GERİ ALINAMAZ iş: yayınlanmış bir
/// sürüm kullanıcının telefonundaki veriyi bozarsa geri döndürülemez —
/// eski sürümü kurmak veriyi geri getirmez. Diğer hataların hepsi bir
/// sonraki sürümle düzeltilebilir, bu düzeltilemez.
///
/// Anlık şema görüntüleri `drift_schemas/` altında. Yeni sürüm eklerken
/// (mobile/ dizininde):
///
///   dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/
///   dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
void main() {
  late SchemaVerifier dogrulayici;

  setUpAll(() {
    dogrulayici = SchemaVerifier(GeneratedHelper());
  });

  test('v9 şeması v10\'a sorunsuz yükseltiliyor', () async {
    final baglanti = await dogrulayici.startAt(9);
    final db = AppDatabase.forTesting(baglanti);

    // Göçü çalıştırır ve sonucu v10'un BEKLENEN şemasıyla karşılaştırır:
    // eksik sütun, fazla sütun, yanlış tür — hepsi burada yakalanır.
    await dogrulayici.migrateAndValidate(db, 10);

    await db.close();
  });

  /// Asıl soru şema değil VERİ: göç mevcut belgeleri bozuyor mu.
  ///
  /// Yüzde iskonto sütunu varsayılan 0 ile ekleniyor ve 0 "yüzde iskonto
  /// yok" demek. Varsayılan yanlış olsaydı (ör. 100) mevcut her teklifin
  /// toplamı sessizce değişirdi — kullanıcı hiçbir şey yapmadan
  /// belgelerinin tutarı kayardı.
  test('göç mevcut belge kalemlerini olduğu gibi bırakır', () async {
    // Üretilmiş şema sınıfları satırları uygulamanın tipli `QuoteItem`
    // sınıfı olarak vermiyor; sütunlar ham okunuyor. Zaten test edilen şey
    // de tam olarak SÜTUNLARIN kendisi.
    late Map<String, Object?> kalem;

    await dogrulayici.testWithDataIntegrity(
      oldVersion: 9,
      newVersion: 10,
      createOld: v9.DatabaseAtV9.new,
      createNew: v10.DatabaseAtV10.new,
      openTestedDatabase: AppDatabase.forTesting,
      createItems: (toplu, eski) {
        // Yabancı anahtar zinciri: kalem → teklif → müşteri → şirket.
        toplu.insertAll(eski.companies, [
          RawValuesInsertable({
            'id': Variable('sirket-1'),
            'name': Variable('Test A.Ş.'),
          }),
        ]);
        toplu.insertAll(eski.customers, [
          RawValuesInsertable({
            'id': Variable('musteri-1'),
            'company_id': Variable('sirket-1'),
            'code': Variable('MUS-1'),
          }),
        ]);
        toplu.insertAll(eski.quotes, [
          RawValuesInsertable({
            'id': Variable('teklif-1'),
            'company_id': Variable('sirket-1'),
            'code': Variable('TKF-1'),
            'customer_id': Variable('musteri-1'),
          }),
        ]);
        toplu.insertAll(eski.quoteItems, [
          RawValuesInsertable({
            'id': Variable('kalem-1'),
            'quote_id': Variable('teklif-1'),
            'description': Variable('Kombi bakımı'),
            'quantity': Variable(2),
            'unit': Variable('adet'),
            'unit_price_minor': Variable(50000),
            'tax_rate': Variable(20),
            'discount_minor': Variable(15000),
          }),
        ]);
      },
      validateItems: (yeni) async {
        final satirlar = await yeni
            .customSelect('SELECT * FROM quote_items')
            .get();
        expect(satirlar, hasLength(1));
        kalem = satirlar.single.data;
      },
    );

    expect(kalem['description'], 'Kombi bakımı');
    expect(kalem['quantity'], 2);
    expect(kalem['unit_price_minor'], 50000);
    expect(kalem['tax_rate'], 20);
    expect(kalem['discount_minor'], 15000, reason: 'tutar iskontosu korunmalı');
    expect(
      kalem['discount_rate'],
      0,
      reason:
          'yeni sütun 0 ile gelmeli — aksi halde mevcut belgelerin toplamı '
          'kullanıcı hiçbir şey yapmadan değişir',
    );
  });
}
