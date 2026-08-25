/// Belge numarası üreteci — bkz. docs/03 § Akıllı Numaralandırma.
///
/// Numara SAYARAK üretilmez. Eski yöntem "kaç kayıt var + 1" idi ve iki
/// yerde bozuluyordu: bir belge silindiğinde numara geri sayıyor ve daha
/// önce kullanılmış bir numarayı yeniden veriyordu; kullanıcı numarayı
/// elle değiştirdiğinde ise bir sonraki belge yine eski seriye dönüyordu.
///
/// Doğru davranış, muhasebe pratiğinin beklediği davranıştır: numara
/// SON KULLANILAN numaradan devam eder. Kullanıcı seriyi (ön ek dahil)
/// istediği yerden başlatabilir; sistem oradan sayar. Yıl değişince sıra
/// 1'e döner ama kullanıcının seçtiği ön ek korunur.
abstract final class DocumentNumbering {
  /// `ONEK-YIL-SIRA` — ön ek harf/rakam/tire içerebilir.
  static final _pattern = RegExp(r'^([A-Za-z0-9İıŞşĞğÜüÖöÇç]+)-(\d{4})-(\d+)$');

  static const _defaultWidth = 5;

  /// [existingCodes] içindeki en güncel seriyi bulup bir sonraki numarayı
  /// üretir. Üretilen numara mevcut bir numarayla çakışırsa boştaki ilk
  /// numaraya kadar ilerler.
  static String next({
    required String fallbackPrefix,
    required Iterable<String> existingCodes,
    DateTime? today,
  }) {
    final year = (today ?? DateTime.now()).year;
    final taken = existingCodes.map((code) => code.trim()).toSet();

    final parsed = taken
        .map(_ParsedCode.tryParse)
        .whereType<_ParsedCode>()
        .toList();

    if (parsed.isEmpty) {
      return _format(fallbackPrefix, year, 1, _defaultWidth);
    }

    // "Son kullanılan seri": en yüksek yıl, onun içinde en yüksek sıra.
    // Kullanıcı ön eki değiştirdiyse yeni ön ek buradan gelir.
    parsed.sort((a, b) {
      final byYear = a.year.compareTo(b.year);
      return byYear != 0 ? byYear : a.sequence.compareTo(b.sequence);
    });
    final latest = parsed.last;

    final sameSeries = parsed.where(
      (code) => code.prefix == latest.prefix && code.year == year,
    );
    final highest = sameSeries.isEmpty
        ? 0
        : sameSeries
              .map((code) => code.sequence)
              .reduce((a, b) => a > b ? a : b);

    var sequence = highest + 1;
    var candidate = _format(latest.prefix, year, sequence, latest.width);
    while (taken.contains(candidate)) {
      sequence++;
      candidate = _format(latest.prefix, year, sequence, latest.width);
    }
    return candidate;
  }

  static String _format(String prefix, int year, int sequence, int width) {
    return '$prefix-$year-${sequence.toString().padLeft(width, '0')}';
  }

  /// Kullanıcının girdiği numaranın kabul edilebilir olup olmadığı.
  ///
  /// Serbest metne izin verilir (her işletmenin kendi düzeni olabilir);
  /// yalnızca boş olmaması ve makul uzunlukta olması aranır.
  static String? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Belge numarası boş olamaz.';
    if (trimmed.length > 50) return 'Belge numarası çok uzun.';
    return null;
  }
}

class _ParsedCode {
  const _ParsedCode({
    required this.prefix,
    required this.year,
    required this.sequence,
    required this.width,
  });

  final String prefix;
  final int year;
  final int sequence;

  /// Sıfır dolgusunun genişliği — kullanıcı `TKF-2026-0100` yazdıysa bir
  /// sonraki numara da dört haneli olmalı.
  final int width;

  static _ParsedCode? tryParse(String code) {
    final match = DocumentNumbering._pattern.firstMatch(code);
    if (match == null) return null;

    final year = int.tryParse(match.group(2)!);
    final sequence = int.tryParse(match.group(3)!);
    if (year == null || sequence == null) return null;

    return _ParsedCode(
      prefix: match.group(1)!,
      year: year,
      sequence: sequence,
      width: match.group(3)!.length,
    );
  }
}
