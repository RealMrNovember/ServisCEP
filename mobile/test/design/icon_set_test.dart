import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tasarım sistemi ikon setinin dışına çıkılmadığını doğrular.
///
/// Neden test: uygulama 150 Material ikonundan tasarım setine geçirildi.
/// Tek bir `Icon(Icons.…)` geri sızdığında hata vermiyor, yalnızca o
/// ekranda başka kalınlıkta bir çizgi beliriyor — ve bu, gözden kaçıp
/// yayına gidiyor. Derleyici bunu yakalayamaz, bu yüzden burada.
void main() {
  test('lib/ içinde Material ikonu kullanılmıyor', () {
    // `Icons.` — ama `TcIcons.` değil: önünde harf olmayan eşleşmeler.
    final desen = RegExp(r'(^|[^A-Za-z])Icons\.');
    final bulunanlar = <String>[];

    for (final girdi in Directory('lib').listSync(recursive: true)) {
      if (girdi is! File || !girdi.path.endsWith('.dart')) continue;
      final satirlar = girdi.readAsLinesSync();
      for (var i = 0; i < satirlar.length; i++) {
        if (desen.hasMatch(satirlar[i])) {
          bulunanlar.add('${girdi.path}:${i + 1}  ${satirlar[i].trim()}');
        }
      }
    }

    expect(
      bulunanlar,
      isEmpty,
      reason:
          'Material ikonu kullanılmış. Tasarım setinden karşılığını seç '
          '(TcIcons) ve TcIcon ile çiz:\n${bulunanlar.join('\n')}',
    );
  });
}
