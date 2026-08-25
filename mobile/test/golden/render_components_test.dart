import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/app/palette.dart';
import 'package:serviscep/app/theme.dart';
import 'package:serviscep/shared/app_bottom_nav.dart';
import 'package:serviscep/shared/app_button.dart';
import 'package:serviscep/shared/skeleton.dart';
import 'package:serviscep/shared/tc_icon.dart';
import 'package:serviscep/shared/ui.dart';

/// Bileşenleri PNG olarak diske çizer — GÖRSEL İNCELEME içindir.
///
/// Bu bir golden KARŞILAŞTIRMA testi değildir; hiçbir şeyi doğrulamaz.
/// Amacı tek: yazılan bileşenin gerçekte nasıl göründüğünü, uygulamayı bir
/// cihaza kurmadan görebilmek. Bileşeni yazıp "herhalde doğru görünüyordur"
/// demek yerine çıktıya bakmak, hizalama ve kontrast hatalarının çoğunu
/// daha yazarken yakalıyor.
///
/// Çalıştırma (mobile/ dizininden):
///   TEKNIKCEP_RENDER_DIR=build/gorsel flutter test test/golden
///
/// Ortam değişkeni verilmezse hiçbir şey yapılmaz; normal test koşusu
/// yavaşlamaz ve CI'da dosya üretilmez.
/// Gömülü fontları test motoruna yükler.
///
/// Test ortamı pubspec'teki fontları KENDİLİĞİNDEN yüklemez; varsayılan
/// test fontu her harfi dolu bir kutu olarak çizer. Bu yüklemeler olmadan
/// çıktılara bakmak anlamsız: tipografi değerlendirilemez, üstelik gri
/// kutular gerçek bir hata sanılabilir.
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
}

void main() {
  final hedefDizin = Platform.environment['TEKNIKCEP_RENDER_DIR'];
  final aktif = hedefDizin != null && hedefDizin.isNotEmpty;

  final yakalamaAnahtari = GlobalKey();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (aktif) await _fontlariYukle();
  });

  /// Verilen parçayı istenen boyutta çizip PNG olarak yazar.
  Future<void> ciz(
    WidgetTester tester,
    String ad,
    Widget parca, {
    required Brightness parlaklik,
    Size boyut = const Size(390, 300),
  }) async {
    if (!aktif) return;

    tester.view.physicalSize = boyut * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepaintBoundary(
        key: yakalamaAnahtari,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: parlaklik == Brightness.dark
              ? AppTheme.dark()
              : AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              backgroundColor: context.palette.bg,
              body: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: parca,
              ),
            ),
          ),
        ),
      ),
    );

    // pumpAndSettle KULLANILMAZ: buton spinner'ı ve iskelet parıltısı
    // sonsuz döngüdür, pumpAndSettle onlarda hiç durulmaz ve zaman aşımına
    // düşer. Bunun yerine belirli bir süre ileri sarılır — iskeletin
    // 500 ms'lik gecikmesini de aşacak kadar.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final dizin = Directory(hedefDizin);
    if (!dizin.existsSync()) dizin.createSync(recursive: true);

    final sinir =
        yakalamaAnahtari.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (sinir == null) return;

    // toImage GERÇEK bir asenkron iş: sonucu motorun raster iş parçacığı
    // üretir. Widget testi ise sahte zamanda (fake async) koşar ve o
    // Future'ı asla ilerletmez — doğrudan await edilirse test SONSUZA
    // KADAR ASILI KALIR, hata da vermez. runAsync gerçek zamana çıkarır.
    final bayt = await tester.runAsync(() async {
      final gorsel = await sinir.toImage(pixelRatio: 2.0);
      final veri = await gorsel.toByteData(format: ui.ImageByteFormat.png);
      gorsel.dispose();
      return veri;
    });
    if (bayt == null) return;

    final sonEk = parlaklik == Brightness.dark ? 'koyu' : 'acik';
    File(
      '$hedefDizin/$ad-$sonEk.png',
    ).writeAsBytesSync(bayt.buffer.asUint8List());
  }

  for (final parlaklik in Brightness.values) {
    final tema = parlaklik == Brightness.dark ? 'koyu' : 'açık';

    testWidgets('$tema tema · butonlar', (tester) async {
      await ciz(
        tester,
        'butonlar',
        parlaklik: parlaklik,
        boyut: const Size(390, 420),
        Column(
          children: [
            AppButton(label: 'Oluştur ve Gönder', onPressed: () {}),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Oluştur ve Gönder',
              onPressed: () {},
              loading: true,
            ),
            const SizedBox(height: AppSpacing.md),
            const AppButton(label: 'Devre Dışı', onPressed: null),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Vazgeç',
              onPressed: () {},
              variant: AppButtonVariant.secondary,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Teklifi Sil',
              icon: 'trash',
              onPressed: () {},
              variant: AppButtonVariant.danger,
            ),
          ],
        ),
      );
    });

    testWidgets('$tema tema · kartlar', (tester) async {
      await ciz(
        tester,
        'kartlar',
        parlaklik: parlaklik,
        boyut: const Size(390, 420),
        Builder(
          builder: (context) => Column(
            children: [
              AppCard(
                child: Text(
                  'Eşitlenmiş kayıt',
                  style: TextStyle(color: context.palette.text),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                pending: true,
                child: Text(
                  'Bekleyen kayıt · sol kenarda uyarı çubuğu',
                  style: TextStyle(color: context.palette.text),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                accent: true,
                child: Text(
                  'Vurgu kart',
                  style: TextStyle(color: context.palette.text),
                ),
              ),
            ],
          ),
        ),
      );
    });

    testWidgets('$tema tema · hata durumu', (tester) async {
      await ciz(
        tester,
        'hata-durumu',
        parlaklik: parlaklik,
        boyut: const Size(390, 560),
        AppErrorState(
          message: 'Teklif listesi yüklenemedi.',
          onRetry: () {},
          onContinueOffline: () {},
        ),
      );
    });

    testWidgets('$tema tema · alt gezinme', (tester) async {
      await ciz(
        tester,
        'alt-gezinme',
        parlaklik: parlaklik,
        boyut: const Size(390, 130),
        Align(
          alignment: Alignment.bottomCenter,
          child: AppBottomNav(
            currentIndex: 1,
            onSelect: (_) {},
            destinations: const [
              AppNavDestination(icon: TcIcons.home, label: 'Ana Sayfa'),
              AppNavDestination(icon: TcIcons.briefcase, label: 'İşler'),
              AppNavDestination(icon: TcIcons.users, label: 'Müşteriler'),
              AppNavDestination(icon: TcIcons.file, label: 'Belgeler'),
              AppNavDestination(icon: TcIcons.grid, label: 'Menü'),
            ],
          ),
        ),
      );
    });

    testWidgets('$tema tema · iskelet', (tester) async {
      await ciz(
        tester,
        'iskelet',
        parlaklik: parlaklik,
        boyut: const Size(390, 300),
        const AppSkeleton(count: 3),
      );
    });
  }
}
