import 'package:intl/intl.dart';

/// Belge para birimi — bkz. docs/04 § Para Hesaplama Kuralı.
///
/// Tutarlar HER ZAMAN en küçük birimde (kuruş/cent) tam sayı olarak
/// saklanır; para birimi yalnızca hangi birim olduğunu ve nasıl
/// gösterileceğini söyler. Kur DÖNÜŞÜMÜ YAPILMAZ: kullanıcı fiyatı hangi
/// para biriminde girdiyse belge o birimde düzenlenir. Otomatik kur
/// çevrimi bilinçli olarak kapsam dışı — güncel kur kaynağı olmadan
/// yapılacak bir çevrim, teklifte yanlış fiyat demektir.
enum Currency {
  try_('TRY', '₺', 'Türk Lirası'),
  usd('USD', '\$', 'Amerikan Doları'),
  eur('EUR', '€', 'Euro');

  const Currency(this.code, this.symbol, this.label);

  final String code;
  final String symbol;
  final String label;

  static Currency fromCode(String? code) => switch (code) {
    'USD' => Currency.usd,
    'EUR' => Currency.eur,
    _ => Currency.try_,
  };
}

/// KDV kipi — kullanıcının girdiği birim fiyatın KDV içerip içermediği.
enum VatMode {
  /// "+ KDV": girilen fiyat KDV hariçtir, üstüne eklenir.
  excluded('EXCLUDED', '+ KDV'),

  /// "KDV dahil": girilen fiyatın içinde KDV vardır, ayrıştırılır.
  included('INCLUDED', 'KDV dahil');

  const VatMode(this.code, this.label);

  final String code;
  final String label;

  static VatMode fromCode(String? code) =>
      code == 'INCLUDED' ? VatMode.included : VatMode.excluded;
}

/// Para hesaplama yardımcıları.
///
/// Para değerleri hiçbir yerde double/float olarak TUTULMAZ. Yalnızca bu
/// dosya, kullanıcıdan gelen metni minor-unit tam sayıya çevirmek veya
/// ekranda göstermek için double kullanır — bu, aritmetik DEĞİL, yalnızca
/// giriş/çıkış formatlamadır.
abstract final class Money {
  static final _formatters = <String, NumberFormat>{};

  static NumberFormat _formatter(Currency currency, bool decimals) {
    final key = '${currency.code}_$decimals';
    return _formatters.putIfAbsent(
      key,
      () => NumberFormat.currency(
        locale: 'tr_TR',
        symbol: currency.symbol,
        decimalDigits: decimals ? 2 : 0,
      ),
    );
  }

  /// "1.234,50" gibi kullanıcı girdisini en küçük birime çevirir.
  static int parseToMinor(String input) {
    final normalized = input
        .trim()
        .replaceAll(RegExp(r'[₺$€\s]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    if (normalized.isEmpty) return 0;
    final value = double.tryParse(normalized) ?? 0;
    return (value * 100).round();
  }

  static String formatMinor(
    int minor, {
    bool decimals = true,
    Currency currency = Currency.try_,
  }) {
    return _formatter(currency, decimals).format(minor / 100);
  }
}

/// Bir belge kaleminin KDV kipine göre hesaplanmış tutarları.
///
/// Hesabın tek yerde toplanması kritik: aynı mantık form ekranında
/// (canlı önizleme), listede ve PDF'te ayrı ayrı yazılırsa er ya da geç
/// birbirinden sapar ve müşteriye giden belgede yanlış tutar çıkar.
class LineAmounts {
  const LineAmounts({
    required this.netMinor,
    required this.vatMinor,
    required this.grossMinor,
  });

  /// KDV hariç tutar.
  final int netMinor;

  /// KDV tutarı.
  final int vatMinor;

  /// KDV dahil tutar.
  final int grossMinor;

  /// [unitPriceMinor] × [quantity] − [discountMinor] üzerinden hesaplar.
  ///
  /// [VatMode.excluded]: girilen fiyat NET kabul edilir, KDV eklenir.
  /// [VatMode.included]: girilen fiyat BRÜT kabul edilir, KDV içinden
  /// ayrıştırılır — brütü bozmadan (net = brüt × 100 / (100 + oran)).
  factory LineAmounts.compute({
    required int quantity,
    required int unitPriceMinor,
    required int discountMinor,
    required int vatRate,
    required VatMode vatMode,
  }) {
    final base = (quantity * unitPriceMinor) - discountMinor;
    final safeBase = base < 0 ? 0 : base;

    if (vatMode == VatMode.included) {
      final net = (safeBase * 100 / (100 + vatRate)).round();
      return LineAmounts(
        netMinor: net,
        vatMinor: safeBase - net,
        grossMinor: safeBase,
      );
    }

    final vat = (safeBase * vatRate / 100).round();
    return LineAmounts(
      netMinor: safeBase,
      vatMinor: vat,
      grossMinor: safeBase + vat,
    );
  }
}

/// Belgenin tamamı için toplamlar.
class DocumentTotals {
  const DocumentTotals({
    required this.netMinor,
    required this.vatMinor,
    required this.grossMinor,
    required this.discountMinor,
  });

  final int netMinor;
  final int vatMinor;
  final int grossMinor;
  final int discountMinor;

  static DocumentTotals from(
    Iterable<LineAmounts> lines, {
    int discountMinor = 0,
  }) {
    var net = 0;
    var vat = 0;
    var gross = 0;
    for (final line in lines) {
      net += line.netMinor;
      vat += line.vatMinor;
      gross += line.grossMinor;
    }
    return DocumentTotals(
      netMinor: net,
      vatMinor: vat,
      grossMinor: gross,
      discountMinor: discountMinor,
    );
  }
}
