import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/app/theme.dart';
import 'package:serviscep/shared/app_button.dart';

/// Butonu belirli bir genişlikte kurar.
Widget _kur(Widget buton, {double genislik = 360}) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: genislik, child: buton),
      ),
    ),
  );
}

void main() {
  // Flutter, hata ayıklama kipinde taşan bir düzen bulduğunda test'i
  // düşürür. Bu yüzden "taşma yok" iddiası, testin hatasız bitmesiyle
  // kanıtlanıyor; ayrıca aşağıda taşma istisnası da açıkça kontrol
  // ediliyor.
  group('Buton taşması', () {
    const uzunEtiket = 'Oluştur ve Müşteriye Gönder';

    for (final genislik in <double>[360, 320, 280, 200]) {
      testWidgets('$genislik dp genişlikte uzun etiket taşmıyor', (
        tester,
      ) async {
        await tester.pumpWidget(
          _kur(
            AppButton(label: uzunEtiket, onPressed: () {}),
            genislik: genislik,
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text(uzunEtiket), findsOneWidget);
      });

      testWidgets('$genislik dp genişlikte spinner + etiket taşmıyor', (
        tester,
      ) async {
        await tester.pumpWidget(
          _kur(
            AppButton(label: uzunEtiket, onPressed: () {}, loading: true),
            genislik: genislik,
          ),
        );

        expect(tester.takeException(), isNull);
        // Yükleme sırasında etiket korunuyor; kullanıcı ne beklediğini
        // bilmeye devam ediyor.
        expect(find.text(uzunEtiket), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    }

    testWidgets('ikon + uzun etiket dar ekranda taşmıyor', (tester) async {
      await tester.pumpWidget(
        _kur(
          AppButton(label: uzunEtiket, icon: 'send', onPressed: () {}),
          genislik: 240,
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('büyük yazı tipi ölçeğinde bile taşmıyor', (tester) async {
      // Erişilebilirlik ayarından yazı tipi büyütülmüş cihaz.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: _kur(
            AppButton(label: uzunEtiket, onPressed: () {}, loading: true),
            genislik: 280,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('Buton davranışı', () {
    testWidgets('yükleme sırasında tıklanamaz', (tester) async {
      var basildi = 0;

      await tester.pumpWidget(
        _kur(
          AppButton(label: 'Kaydet', loading: true, onPressed: () => basildi++),
        ),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(basildi, 0);
    });

    testWidgets('onPressed null ise tıklanamaz', (tester) async {
      await tester.pumpWidget(
        _kur(const AppButton(label: 'Kaydet', onPressed: null)),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('etkinken basılınca çalışır', (tester) async {
      var basildi = 0;

      await tester.pumpWidget(
        _kur(AppButton(label: 'Kaydet', onPressed: () => basildi++)),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(basildi, 1);
    });
  });
}
