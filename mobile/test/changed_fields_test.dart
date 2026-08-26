import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/core/sync/changed_fields.dart';

/// Sunucunun otomatik çakışma birleştirmesi tamamen bu listeye güveniyor.
/// Yanlış bir liste iki yönde de zarar veriyor: eksik bildirilen bir alan
/// sessizce kaybolur, fazla bildirilen bir alan sunucudaki değişikliği ezer.
void main() {
  group('degisenAlanlar', () {
    test('yalnızca değeri farklı olan anahtarları döner', () {
      final degisen = degisenAlanlar(
        {'phone': '0500', 'notes': 'eski'},
        {'phone': '0500', 'notes': 'yeni'},
      );

      expect(degisen, ['notes']);
    });

    test('hiçbir şey değişmediyse boş liste döner', () {
      expect(degisenAlanlar({'a': 1}, {'a': 1}), isEmpty);
    });

    test('null ile gerçek değer arasındaki geçişi yakalar', () {
      expect(degisenAlanlar({'iban': null}, {'iban': 'TR00'}), ['iban']);
      expect(degisenAlanlar({'iban': 'TR00'}, {'iban': null}), ['iban']);
    });

    /// Liste alanları her kaydetmede yeni bir nesne olarak üretiliyor.
    /// Referansla karşılaştırılsalardı alan hiç değişmediği hâlde
    /// "değişti" görünür ve sunucuda gereksiz çakışma üretirdi.
    test('aynı içerikli farklı liste nesnelerini değişmiş saymaz', () {
      final degisen = degisenAlanlar(
        {
          'tags': ['a', 'b'],
        },
        {
          'tags': ['a', 'b'],
        },
      );

      expect(degisen, isEmpty);
    });

    test('liste içeriği farklıysa değişmiş sayar', () {
      final degisen = degisenAlanlar(
        {
          'tags': ['a'],
        },
        {
          'tags': ['a', 'b'],
        },
      );

      expect(degisen, ['tags']);
    });

    /// Eski kayıt bulunamadıysa hiçbir şey varsayılmaz: tüm alanlar
    /// değişmiş sayılır. Bu, sunucuda birleştirmenin reddedilmesine yol
    /// açar — bilmediğimiz bir durumda çakışma göstermek, yanlış
    /// birleştirmekten iyidir.
    test('eski kayıt yoksa tüm alanları değişmiş sayar', () {
      final degisen = degisenAlanlar(null, {'a': 1, 'b': 2});

      expect(degisen, ['a', 'b']);
    });
  });
}
