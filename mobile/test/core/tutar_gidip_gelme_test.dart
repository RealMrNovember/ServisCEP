import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/core/utils/money.dart';

/// Tutarın forma yazılıp geri okunması — gidip gelme (round-trip).
///
/// Bu, projede ÜÇÜNCÜ kez yaşanan aynı hata. Bir tutar alanı önceden
/// doldurulurken `(minor / 100).toString()` ya da `.toStringAsFixed(2)`
/// kullanıldığında NOKTALI bir metin çıkıyor ("2400.0" / "2400.00").
/// [Money.parseToMinor] Türkçe biçimi okuduğu için noktayı BİNLİK
/// AYIRACI sayıp siliyor ve tutar her kaydedişte on ya da yüz katına
/// çıkıyor.
///
/// Sessiz bir hata: kullanıcı formu açar, fiyata hiç dokunmadan
/// kaydeder, tutar değişir. Ürün fiyatları tekliflere kalem olarak
/// giriyor, teklif tutarı müşteriye giden PDF'e ve cari hesaba
/// yürüyor — yani hata en sonunda müşterinin borcunda görünüyor.
void main() {
  group('Money.formatMinorPlain ↔ parseToMinor', () {
    const ornekler = <int>[
      0,
      1, // 1 kuruş
      50,
      99,
      100, // ₺1
      12345, // ₺123,45
      240000, // ₺2.400 — canlıda 10x/100x olan tutar
      100000000, // ₺1.000.000
    ];

    for (final kurus in ornekler) {
      test('$kurus kuruş gidip geldiğinde değişmiyor', () {
        final metin = Money.formatMinorPlain(kurus);
        expect(
          Money.parseToMinor(metin),
          kurus,
          reason:
              'formatMinorPlain($kurus) = "$metin" geri okunduğunda '
              '$kurus olmalı.',
        );
      });
    }

    test('bozuk biçimler gerçekten bozuk okunuyor (hatanın kanıtı)', () {
      // Bu testin amacı düzeltmenin gerekliliğini kayda geçirmek:
      // aşağıdaki iki biçim tutarı değiştiriyor, bu yüzden yasak.
      expect(Money.parseToMinor((240000 / 100).toString()), isNot(240000));
      expect(
        Money.parseToMinor((240000 / 100).toStringAsFixed(2)),
        isNot(240000),
      );
    });
  });

  test('tutar alanları formatMinorPlain ile dolduruluyor', () {
    // Bekçi: yasak biçimlerden biri lib/ içine geri sızarsa yakalanır.
    final desen = RegExp(r'Minor\s*/\s*100\)\s*\.\s*toString');
    final kacaklar = <String>[];

    for (final girdi in Directory('lib').listSync(recursive: true)) {
      if (girdi is! File || !girdi.path.endsWith('.dart')) continue;
      final satirlar = girdi.readAsLinesSync();
      for (var i = 0; i < satirlar.length; i++) {
        if (desen.hasMatch(satirlar[i])) {
          kacaklar.add('${girdi.path}:${i + 1}  ${satirlar[i].trim()}');
        }
      }
    }

    expect(
      kacaklar,
      isEmpty,
      reason:
          'Tutar bir metin alanına "(minor / 100).toString()" ile '
          'yazılmış. Money.formatMinorPlain(minor) kullan; aksi hâlde '
          'kayıt sırasında tutar katlanır:\n${kacaklar.join('\n')}',
    );
  });
}
