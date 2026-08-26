import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:serviscep/app/theme.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:serviscep/core/database/app_database.dart';
import 'package:serviscep/core/providers/core_providers.dart';
import 'package:serviscep/features/auth/data/auth_repository.dart';
import 'package:serviscep/features/auth/data/session_controller.dart';
import 'package:serviscep/features/customers/customers_list_screen.dart';
import 'package:serviscep/features/dashboard/dashboard_screen.dart';
import 'package:serviscep/features/documents/documents_screen.dart';
import 'package:serviscep/features/jobs/jobs_list_screen.dart';

import '../support/fake_sync_api_client.dart';
import '../support/fake_token_store.dart';
import '../support/in_memory_database.dart';

/// Play mağaza ekran görüntülerini üretir.
///
/// NEDEN GERÇEK CİHAZ/EMÜLATÖR DEĞİL:
///
/// 1. Mağaza sayfası HERKESE AÇIK. Gerçek bir hesapla çekilen görüntüler
///    o hesabın müşteri adlarını, telefonlarını ve IBAN'ını Google Play'de
///    yayınlar. Kurgulanmış veri bu riski tamamen ortadan kaldırıyor.
/// 2. Yeniden üretilebilir. Ekran değiştiğinde görüntüler tek komutla
///    tazeleniyor; kimse emülatör kurup elle gezinmiyor.
/// 3. Piksel boyutu kesin. Play en/boy oranını reddedebiliyor; burada
///    çözünürlük koddan geliyor, cihazın çözünürlüğünden değil.
///
/// Çalıştırma (mobile/ dizininden):
///   TEKNIKCEP_STORE_DIR=../assets/branding/store flutter test test/store
///
/// Ortam değişkeni verilmezse hiçbir şey yapılmaz — normal test koşusu
/// yavaşlamaz ve CI'da dosya üretilmez.

/// Play, en/boy oranını 16:9 ile 9:16 arasında istiyor. 1080x1920 tam
/// 9:16 — daha uzun modern oranlar (20:9) REDDEDİLİYOR.
const _mantiksalEn = 360.0;
const _mantiksalBoy = 640.0;
const _pikselOrani = 3.0;

const _sirketId = 'demo-sirket';

/// Oturumu sabitler.
///
/// Gerçek depo açılışta güvenli depodan jeton okumaya çalışıyor; test
/// ortamında platform kanalı yok, oturum boş dönüyor ve ekranlar
/// "oturum yok" durumunda çiziliyordu. Yalnızca `restoreSession`
/// eziliyor — denetleyicinin geri kalanı gerçek koddan geçiyor.
class _SahteAuthDeposu extends AuthRepository {
  _SahteAuthDeposu(AppDatabase db)
    : super(
        db,
        const FlutterSecureStorage(),
        FakeSyncApiClient(),
        FakeTokenStore(),
      );

  @override
  Future<AuthSession?> restoreSession() async => const AuthSession(
    userId: 'demo-kullanici',
    companyId: _sirketId,
    fullName: 'Mert Aydın',
    companyName: 'Aydın Teknik Servis',
  );
}

Future<void> _fontlariYukle() async {
  const aileler = <String, List<String>>{
    'Barlow': [
      'assets/fonts/Barlow-Regular.ttf',
      'assets/fonts/Barlow-Medium.ttf',
      'assets/fonts/Barlow-SemiBold.ttf',
      'assets/fonts/Barlow-Bold.ttf',
    ],
    'Archivo': [
      'assets/fonts/Archivo-SemiBold.ttf',
      'assets/fonts/Archivo-Bold.ttf',
    ],
    'JetBrainsMono': [
      'assets/fonts/JetBrainsMono-Medium.ttf',
      'assets/fonts/JetBrainsMono-SemiBold.ttf',
      'assets/fonts/JetBrainsMono-Bold.ttf',
    ],
    'Roboto': [
      'assets/fonts/Roboto-Regular.ttf',
      'assets/fonts/Roboto-Medium.ttf',
      'assets/fonts/Roboto-Bold.ttf',
    ],
  };

  for (final girdi in aileler.entries) {
    final yukleyici = FontLoader(girdi.key);
    for (final yol in girdi.value) {
      yukleyici.addFont(rootBundle.load(yol));
    }
    await yukleyici.load();
  }

  // Material ikon fontu AYRICA yükleniyor. Test ortamı onu kendiliğinden
  // yüklemiyor ve yüklenmediğinde her ikon boş bir kutu olarak çiziliyor
  // — ilk denemede ekran görüntülerindeki bütün ikonlar kutuydu ve bu
  // gerçek bir arayüz hatası sanılabilirdi.
  final ikonlar = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await ikonlar.load();
}

/// Demo veriyi doğrudan tablolara yazar.
///
/// Depo sınıflarının `create()` metotları KULLANILMIYOR: onlar aynı
/// zamanda senkron kuyruğuna satır düşüyor ve kayıtlar PENDING görünüyor.
/// Ekran görüntülerinde her kartın kenarında "bekliyor" şeridi olurdu.
Future<void> _demoVeriYaz(AppDatabase db) async {
  // Tarihler BUGÜNE göre kuruluyor, sabit bir güne değil: pano
  // "bugünün işleri"ni filtreliyor ve sabit tarihle ekran her zaman
  // "bugün planlanmış iş yok" gösteriyordu.
  final simdi = DateTime.now();
  final bugun = DateTime(simdi.year, simdi.month, simdi.day, 9, 30);

  await db
      .into(db.companies)
      .insert(
        CompaniesCompanion.insert(id: _sirketId, name: 'Aydın Teknik Servis'),
      );

  const musteriler = [
    ('m1', 'MUS-0041', 'Selin Kaya', null, 'BIREYSEL', '0532 118 40 27', 'Kadıköy'),
    ('m2', 'MUS-0040', null, 'Yıldız Sitesi Yönetimi', 'SITE', '0216 445 12 08', 'Ataşehir'),
    ('m3', 'MUS-0039', 'Burak Demir', 'Demir Gıda Ltd.', 'FIRMA', '0533 204 71 65', 'Ümraniye'),
    ('m4', 'MUS-0038', 'Elif Şahin', null, 'BIREYSEL', '0555 913 22 04', 'Maltepe'),
    ('m5', 'MUS-0037', null, 'Marmara Apartmanı', 'APARTMAN', '0216 377 90 15', 'Kartal'),
  ];

  for (final (id, kod, yetkili, firma, tur, telefon, ilce) in musteriler) {
    await db
        .into(db.customers)
        .insert(
          CustomersCompanion.insert(
            id: id,
            companyId: _sirketId,
            code: kod,
            contactName: Value(yetkili),
            companyName: Value(firma),
            type: Value(tur),
            phone: Value(telefon),
            il: const Value('İstanbul'),
            ilce: Value(ilce),
            syncStatus: const Value('SYNCED'),
          ),
        );
  }

  const isler = [
    ('i1', 'IS-0132', 'm1', 'Kombi bakımı ve petek temizliği', 'DEVAM_EDIYOR', 'YUKSEK', 285000),
    ('i2', 'IS-0131', 'm2', 'Site otoparkı kamera arızası', 'PLANLANDI', 'YUKSEK', 640000),
    ('i3', 'IS-0130', 'm3', 'Soğuk oda termostat değişimi', 'PLANLANDI', 'NORMAL', 175000),
    ('i4', 'IS-0129', 'm4', 'Elektrik tesisatı kontrolü', 'TAMAMLANDI', 'NORMAL', 90000),
    ('i5', 'IS-0128', 'm5', 'Asansör makine dairesi bakımı', 'TAMAMLANDI', 'DUSUK', 420000),
  ];

  for (var i = 0; i < isler.length; i++) {
    final (id, kod, musteri, baslik, durum, oncelik, tutar) = isler[i];
    await db
        .into(db.jobs)
        .insert(
          JobsCompanion.insert(
            id: id,
            companyId: _sirketId,
            code: kod,
            customerId: musteri,
            title: baslik,
            status: Value(durum),
            priority: Value(oncelik),
            appointmentDate: Value(bugun.add(Duration(hours: i * 2))),
            startTime: Value('${(9 + i * 2).toString().padLeft(2, '0')}:00'),
            estimatedPriceMinor: Value(tutar),
            syncStatus: const Value('SYNCED'),
          ),
        );
  }

  const teklifler = [
    ('t1', 'TKF-2026-0042', 'm2', 'GONDERILDI', 1845000),
    ('t2', 'TKF-2026-0041', 'm3', 'KABUL_EDILDI', 926000),
    ('t3', 'TKF-2026-0040', 'm1', 'TASLAK', 312000),
    ('t4', 'TKF-2026-0039', 'm4', 'KABUL_EDILDI', 158000),
    ('t5', 'TKF-2026-0038', 'm5', 'GONDERILDI', 2240000),
  ];

  for (final (id, kod, musteri, durum, tutar) in teklifler) {
    await db
        .into(db.quotes)
        .insert(
          QuotesCompanion.insert(
            id: id,
            companyId: _sirketId,
            code: kod,
            customerId: musteri,
            status: Value(durum),
            totalMinor: Value(tutar),
            syncStatus: const Value('SYNCED'),
          ),
        );
  }
}

void main() {
  final hedefDizin = Platform.environment['TEKNIKCEP_STORE_DIR'];
  final aktif = hedefDizin != null && hedefDizin.isNotEmpty;

  final yakalamaAnahtari = GlobalKey();
  late AppDatabase db;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (!aktif) return;
    // Ekranlar tarihleri Türkçe biçimliyor; başlatılmadan çizim
    // LocaleDataException ile düşüyor.
    await initializeDateFormatting('tr_TR');
    await _fontlariYukle();
  });

  setUp(() async {
    if (!aktif) return;
    db = createInMemoryDatabase();
    await _demoVeriYaz(db);
  });

  tearDown(() async {
    if (aktif) await db.close();
  });

  Future<void> cek(WidgetTester tester, String ad, Widget ekran) async {
    if (!aktif) return;

    tester.view.physicalSize = const Size(
      _mantiksalEn * _pikselOrani,
      _mantiksalBoy * _pikselOrani,
    );
    tester.view.devicePixelRatio = _pikselOrani;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionControllerProvider.overrideWith(
            (ref) => SessionController(_SahteAuthDeposu(db)),
          ),
        ],
        child: RepaintBoundary(
          key: yakalamaAnahtari,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            home: ekran,
          ),
        ),
      ),
    );

    // pumpAndSettle KULLANILMIYOR: iskelet parıltısı ve senkron göstergesi
    // sonsuz döngü; pumpAndSettle onlarda hiç durulmaz ve zaman aşımına
    // düşer.
    //
    // Tek bir pump da yetmiyor. İki iş GERÇEK zamanda ilerliyor:
    // veritabanı akışının ilk değeri ve SVG ikonlarının çözülmesi. Sahte
    // zamanda pump etmek onları ilerletmiyor — ilk denemede listeler
    // iskelet, ikonlar boş kare çıktı. runAsync ile gerçek zamana çıkıp
    // aralarda kare çizdiriyoruz.
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }

    final dizin = Directory(hedefDizin);
    if (!dizin.existsSync()) dizin.createSync(recursive: true);

    final sinir =
        yakalamaAnahtari.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (sinir == null) return;

    // toImage GERÇEK bir asenkron iş; widget testi sahte zamanda koştuğu
    // için doğrudan await edilirse test sonsuza kadar asılı kalır.
    final bayt = await tester.runAsync(() async {
      final gorsel = await sinir.toImage(pixelRatio: _pikselOrani);
      final veri = await gorsel.toByteData(format: ui.ImageByteFormat.png);
      gorsel.dispose();
      return veri;
    });
    if (bayt == null) return;

    File(
      '$hedefDizin/$ad.png',
    ).writeAsBytesSync(bayt.buffer.asUint8List(), flush: true);

    // Zamanlayıcılar hem AĞAÇ AYAKTAYKEN hem SÖKÜLDÜKTEN SONRA
    // boşaltılıyor ve bunun iki ayrı sebebi var:
    //
    // - Önce boşaltılmazsa, iskeletin gecikmeli geri çağrısı ağaç
    //   sökülmüşken setState çağırıyor ("defunct element").
    // - Sonra boşaltılmazsa, ilk boşaltma sırasında kurulan yeni bir
    //   zamanlayıcı (senkron şeridinin 2 sn'lik gizlemesi) sökümden
    //   sonra bekliyor kalıyor ("A Timer is still pending").
    //
    // Her iki boşaltmada da İKİ tür zamanlayıcı ayrı ayrı ilerletiliyor:
    // runAsync içinde kurulanlar GERÇEK zamanda, normal pump sırasında
    // kurulanlar (ör. iskeletin 500 ms'lik gecikmesi) SAHTE zamanda.
    Future<void> zamanlayicilariBosalt() async {
      await tester.pump(const Duration(seconds: 3));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2500)),
      );
      await tester.pump(const Duration(seconds: 3));
    }

    await zamanlayicilariBosalt();
    await tester.pumpWidget(const SizedBox.shrink());
    await zamanlayicilariBosalt();
  }

  testWidgets('01 pano', (t) => cek(t, '01-pano', const DashboardScreen()));
  testWidgets('02 isler', (t) => cek(t, '02-isler', const JobsListScreen()));
  testWidgets(
    '03 musteriler',
    (t) => cek(t, '03-musteriler', const CustomersListScreen()),
  );
  testWidgets(
    '04 belgeler',
    (t) => cek(t, '04-belgeler', const DocumentsScreen()),
  );
}
