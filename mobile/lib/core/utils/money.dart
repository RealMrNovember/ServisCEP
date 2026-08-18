import 'package:intl/intl.dart';

/// Para hesaplama yardımcıları — bkz. docs/04 § Para Hesaplama Kuralı.
///
/// Para değerleri hiçbir yerde double/float olarak TUTULMAZ. Yalnızca bu
/// dosya, kullanıcıdan gelen metni (TL) minor-unit (kuruş) tam sayıya
/// çevirmek veya ekranda göstermek için double kullanır — bu, aritmetik
/// DEĞİL, yalnızca giriş/çıkış formatlamadır.
abstract final class Money {
  static final _formatter = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  static final _formatterNoDecimals = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 0,
  );

  /// "1.234,50" gibi kullanıcı girdisini kuruş cinsinden tam sayıya çevirir.
  static int parseToMinor(String input) {
    final normalized = input
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .replaceAll('₺', '')
        .trim();
    if (normalized.isEmpty) return 0;
    final value = double.tryParse(normalized) ?? 0;
    return (value * 100).round();
  }

  static String formatMinor(int minor, {bool decimals = true}) {
    final value = minor / 100;
    return decimals ? _formatter.format(value) : _formatterNoDecimals.format(value);
  }
}
