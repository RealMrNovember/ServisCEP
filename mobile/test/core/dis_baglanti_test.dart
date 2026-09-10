import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/core/utils/dis_baglanti.dart';

/// Dış bağlantıların SINIRLARI.
///
/// Bu alanda gerçek bir üretim hatası yaşandı: `AndroidManifest.xml`
/// içinde `<queries>` altında `ACTION_VIEW` bildirilmediği için Android
/// 11+ cihazlarda `url_launcher` hiçbir hedefi çözemiyordu. `launchUrl`
/// istisna fırlatmıyor, sessizce `false` dönüyor — ve dönüş değeri hiçbir
/// çağrı yerinde okunmuyordu. Sonuç: gizlilik politikası, telefon arama,
/// harita ve WhatsApp destek düğmesi basıldığında HİÇBİR ŞEY olmuyordu.
/// Kullanıcı bunun bir hata olduğunu anlayamadı, biz de aylarca
/// göremedik.
///
/// Buradaki testler o iki savunma hattını da kilitliyor.
void main() {
  group('manifest', () {
    late String manifest;

    setUpAll(() {
      manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
    });

    test('url_launcher için paket görünürlüğü bildirilmiş', () {
      // Bunlar olmadan Android 11+ cihazda her dış bağlantı ölü.
      for (final sema in ['https', 'tel', 'mailto']) {
        expect(
          manifest,
          contains('android:scheme="$sema"'),
          reason:
              '<queries> içinde "$sema" şeması bildirilmemiş. Android 11+ '
              'paket görünürlüğü yüzünden bu şemayı kullanan her bağlantı '
              'sessizce açılmaz.',
        );
      }
      expect(manifest, contains('android.intent.action.VIEW'));
    });
  });

  test('launchUrl doğrudan çağrılmıyor, DisBaglanti üzerinden geçiliyor', () {
    // Tek kapı olmasının sebebi: dönüş değerini okumayı unutmanın
    // maliyeti, sessizce ölü bir düğme.
    final kacaklar = <String>[];

    for (final girdi in Directory('lib').listSync(recursive: true)) {
      if (girdi is! File || !girdi.path.endsWith('.dart')) continue;
      if (girdi.path.endsWith('dis_baglanti.dart')) continue;

      final satirlar = girdi.readAsLinesSync();
      for (var i = 0; i < satirlar.length; i++) {
        if (satirlar[i].contains('launchUrl(')) {
          kacaklar.add('${girdi.path}:${i + 1}  ${satirlar[i].trim()}');
        }
      }
    }

    expect(
      kacaklar,
      isEmpty,
      reason:
          'launchUrl doğrudan çağrılmış. Bunun yerine '
          'context.disBaglantiAc(uri) kullan; açılamadığında kullanıcıya '
          'söylüyor ve adresi panoya kopyalıyor:\n${kacaklar.join('\n')}',
    );
  });

  test('açılamayan bağlantıda çağıran bilgilendirilir', () async {
    // Hedefi açacak uygulama YOKMUŞ gibi: gerçek üretim hatasında
    // Android tam olarak bunu yapıyordu — istisna yok, yalnızca `false`.
    final mesajlar = <String>[];

    final sonuc = await DisBaglanti.ac(
      Uri.https('ornek.test', '/belge'),
      mesajGoster: mesajlar.add,
      baslatici: (_) async => false,
    );

    expect(sonuc, isFalse);
    expect(mesajlar, hasLength(1));
    expect(mesajlar.single, contains('açılamadı'));
  });

  test('başlatıcı istisna fırlatsa da sessiz kalınmaz', () async {
    // Eklenti ileride başka bir istisna türü eklerse de kullanıcı
    // bilgilendirilmeli; bu yüzden `on Object` yakalanıyor.
    final mesajlar = <String>[];

    final sonuc = await DisBaglanti.ac(
      Uri.https('ornek.test', '/belge'),
      mesajGoster: mesajlar.add,
      baslatici: (_) async => throw StateError('hedef yok'),
    );

    expect(sonuc, isFalse);
    expect(mesajlar, hasLength(1));
  });

  test('açılabilen bağlantıda kullanıcı rahatsız edilmez', () async {
    final mesajlar = <String>[];

    final sonuc = await DisBaglanti.ac(
      Uri.https('ornek.test', '/belge'),
      mesajGoster: mesajlar.add,
      baslatici: (_) async => true,
    );

    expect(sonuc, isTrue);
    expect(mesajlar, isEmpty);
  });

  testWidgets('ekranda SnackBar olarak görünür', (tester) async {
    // İşin Future'i YAKALANIYOR ve bekleniyor. `pumpAndSettle` yalnızca
    // zamanlanmış kareleri bekliyor; dokunma anında henüz animasyon
    // yokken hemen dönüyor ve SnackBar sonradan ekleniyordu.
    Future<bool>? islem;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => islem = context.disBaglantiAc(
                Uri.https('ornek.test', '/belge'),
                baslatici: (_) async => false,
              ),
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aç'));
    await islem;
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('açılamadı'), findsOneWidget);
  });
}
