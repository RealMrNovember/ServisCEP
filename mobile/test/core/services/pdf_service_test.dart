import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:serviscep/core/database/app_database.dart';
import 'package:serviscep/core/services/pdf_service.dart';
import 'package:serviscep/core/utils/money.dart';

/// Belge motorunun testi.
///
/// PDF'in görsel doğruluğu otomatik doğrulanamaz; buradaki testler
/// belgenin ÜRETİLEBİLDİĞİNİ ve içindeki tutarların KDV kipine göre
/// doğru olduğunu güvenceye alır. Ayrıca `TEKNIKCEP_SAMPLE_DIR` ortam
/// değişkeni verilirse gerçek bir örnek belge diske yazılır — tasarımı
/// gözle kontrol etmek için (bkz. tool/README).
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('tr_TR');
  });

  final company = Company(
    id: 'company-1',
    name: 'Yıldız Elektrik ve Güvenlik Sistemleri Ltd. Şti.',
    businessTypes: 'Elektrik,Kamera / Güvenlik',
    iban: 'TR33 0006 1005 1978 6457 8413 26',
    address: 'Cumhuriyet Mah. Şehit Fethi Bey Cad. No:128/A Konak / İzmir',
    phone: '0232 441 55 66',
    email: 'info@yildizelektrik.com.tr',
    taxInfo: 'Konak V.D. 9250473118',
    logoPath: 'test/fixtures/ornek-firma-logo.png',
    hasLogo: true,
    createdAt: DateTime(2026, 1, 5),
  );

  final customer = Customer(
    id: 'customer-1',
    companyId: 'company-1',
    code: 'MUS-2026-0042',
    contactName: 'Ayşe Çağlayan',
    companyName: 'Ege Yapı Denetim A.Ş.',
    type: 'FIRMA',
    phone: '0232 335 12 90',
    email: 'muhasebe@egeyapidenetim.com',
    address: 'Adalet Mah. Manas Bulvarı No:47 Kat:6 D:601',
    il: 'İzmir',
    ilce: 'Bayraklı',
    taxInfo: 'Bayraklı V.D. 3120558974',
    hasTaxCertificate: false,
    logoPath: 'test/fixtures/ornek-musteri-logo.png',
    hasLogo: true,
    syncStatus: 'SYNCED',
    version: 1,
    createdAt: DateTime(2026, 3, 12),
  );

  final items = <PdfLineItem>[
    const PdfLineItem(
      description:
          'Hikvision 4MP ColorVu IP Bullet Kamera (DS-2CD2047G2-LU) — '
          'gece renkli görüntü, dahili mikrofon',
      quantity: 8,
      unit: 'adet',
      unitPriceMinor: 289000,
      taxRate: 20,
      discountMinor: 0,
    ),
    const PdfLineItem(
      description: '16 Kanal PoE NVR + 4 TB Surveillance HDD',
      quantity: 1,
      unit: 'adet',
      unitPriceMinor: 1475000,
      taxRate: 20,
      discountMinor: 75000,
    ),
    const PdfLineItem(
      description: 'CAT6 U/UTP kablo çekimi ve kanal montajı',
      quantity: 240,
      unit: 'metre',
      unitPriceMinor: 4200,
      taxRate: 20,
      discountMinor: 0,
    ),
    const PdfLineItem(
      description: 'Sistem kurulumu, konfigürasyon ve personel eğitimi',
      quantity: 1,
      unit: 'hizmet',
      unitPriceMinor: 850000,
      taxRate: 20,
      discountMinor: 0,
    ),
  ];

  Future<List<int>> render({
    VatMode vatMode = VatMode.excluded,
    Currency currency = Currency.try_,
    String documentTitle = 'Teklif Formu',
    String code = 'TKF-2026-0117',
    String? introText,
  }) async {
    final doc = await PdfService.buildQuoteOrProformaDocument(
      documentTitle: documentTitle,
      introText: introText,
      code: code,
      date: DateTime(2026, 8, 25),
      validUntil: DateTime(2026, 9, 9),
      company: company,
      customer: customer,
      items: items,
      currency: currency,
      vatMode: vatMode,
      vatRate: 20,
      preparedBy: 'Muzaffer Yıldız',
      paymentTerms: '%50 sipariş onayında, %50 teslimatta.',
      deliveryTime: 'Sipariş onayından sonra 5 iş günü.',
      warrantyTerms: '2 yıl ürün, 1 yıl işçilik garantisi.',
      notes:
          'Fiyatlarımıza montaj, kablolama ve devreye alma dahildir. '
          'Çalışma alanındaki elektrik altyapısının hazır olması '
          'gerekmektedir.',
    );
    return doc.save();
  }

  test('teklif belgesi üretilebiliyor ve PDF olarak geçerli', () async {
    final bytes = await render();

    expect(bytes.length, greaterThan(1000));
    // PDF dosya imzası — belgenin gerçekten PDF olarak kapandığını gösterir.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('KDV dahil kipinde brüt tutar değişmez, KDV içeriden ayrışır', () {
    const line = PdfLineItem(
      description: 'Test',
      quantity: 2,
      unit: 'adet',
      unitPriceMinor: 6000,
      taxRate: 20,
      discountMinor: 0,
    );

    final excluded = line.amounts(VatMode.excluded);
    expect(excluded.netMinor, 12000);
    expect(excluded.vatMinor, 2400);
    expect(excluded.grossMinor, 14400);

    final included = line.amounts(VatMode.included);
    expect(
      included.grossMinor,
      12000,
      reason: 'girilen fiyat brüt kabul edilir',
    );
    expect(included.netMinor, 10000);
    expect(included.vatMinor, 2000);
  });

  test('iskonto satır tutarından düşülür', () {
    const line = PdfLineItem(
      description: 'Test',
      quantity: 1,
      unit: 'adet',
      unitPriceMinor: 10000,
      taxRate: 20,
      discountMinor: 2000,
    );

    expect(line.amounts(VatMode.excluded).netMinor, 8000);
    expect(line.amounts(VatMode.excluded).grossMinor, 9600);
  });

  test('örnek belgeler istendiğinde diske yazılır', () async {
    final dir = Platform.environment['TEKNIKCEP_SAMPLE_DIR'];
    if (dir == null || dir.isEmpty) {
      return;
    }

    final outDir = Directory(dir);
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    await File('$dir/ornek-teklif-kdv-haric.pdf').writeAsBytes(await render());
    await File(
      '$dir/ornek-teklif-kdv-dahil.pdf',
    ).writeAsBytes(await render(vatMode: VatMode.included));
    await File(
      '$dir/ornek-teklif-usd.pdf',
    ).writeAsBytes(await render(currency: Currency.usd));
    await File('$dir/ornek-proforma-fatura.pdf').writeAsBytes(
      await render(documentTitle: 'Proforma Fatura', code: 'PRF-2026-00043'),
    );
  });

  group('KDV metinleri', () {
    // Kalem editörü satır BAŞINA oran seçtiriyor. Belge tek bir orandan
    // söz ederse karma oranlı teklifte müşteriye yanlış bilgi gider.
    PdfLineItem kalem(int oran) => PdfLineItem(
      description: 'Kalem',
      quantity: 1,
      unit: 'adet',
      unitPriceMinor: 100000,
      taxRate: oran,
      discountMinor: 0,
    );

    test('tüm satırlar aynı orandaysa oran yazılır', () {
      final metin = PdfService.vatTexts(
        items: [kalem(20), kalem(20)],
        vatMode: VatMode.excluded,
      );

      expect(metin.rowLabel, 'KDV (%20)');
      expect(metin.caption, contains('%20 KDV ilave edilecektir'));
    });

    test('karma oranlı belgede tek bir oran YAZILMAZ', () {
      final metin = PdfService.vatTexts(
        items: [kalem(20), kalem(10)],
        vatMode: VatMode.excluded,
      );

      expect(metin.rowLabel, 'KDV');
      expect(metin.rowLabel, isNot(contains('%')));
      expect(metin.caption, contains('her satırda belirtilen oranda'));
      expect(metin.caption, isNot(contains('%20')));
      expect(metin.caption, isNot(contains('%10')));
    });

    test('tüm satırlar %0 ise anlamsız cümle kurulmaz', () {
      final metin = PdfService.vatTexts(
        items: [kalem(0), kalem(0)],
        vatMode: VatMode.excluded,
      );

      expect(metin.rowLabel, 'KDV (%0)');
      expect(metin.caption, 'Fiyatlarımıza KDV uygulanmamıştır.');
      expect(metin.caption, isNot(contains('%0 KDV ilave')));
    });

    test('KDV dahil kipinde oran cümleye karışmaz', () {
      final metin = PdfService.vatTexts(
        items: [kalem(20), kalem(10)],
        vatMode: VatMode.included,
      );

      expect(metin.caption, 'Fiyatlarımıza KDV dahildir.');
    });

    test('hiç kalem yoksa yedek orana düşer', () {
      final metin = PdfService.vatTexts(
        items: const [],
        vatMode: VatMode.excluded,
        fallbackRate: 20,
      );

      expect(metin.rowLabel, 'KDV (%20)');
    });
  });
}
