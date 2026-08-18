/// Akıllı numaralandırma yardımcısı — bkz. docs/03 § Akıllı Numaralandırma.
///
/// NOT: docs/03 kuralı belge numarasının SUNUCU tarafında, transaction-safe
/// üretilmesini zorunlu kılar. Backend (Phase 3) henüz derinleşmediği için
/// bu, geçici bir YEREL sıra üretecidir — sync katmanı eklendiğinde sunucu
/// tarafından üretilen numaralarla uzlaştırılacaktır (bkz. ROADMAP.md).
abstract final class CodeGenerator {
  static String next(String prefix, int existingCountThisYear) {
    final year = DateTime.now().year;
    final seq = (existingCountThisYear + 1).toString().padLeft(5, '0');
    return '$prefix-$year-$seq';
  }
}
