import '../database/app_database.dart';

/// Firma adı varsa firma adı, yoksa yetkili adı soyadı gösterilir — bkz.
/// docs/02 § Müşteri Profili. Backend Customer::displayName ile tutarlı
/// olmalıdır.
extension CustomerDisplayName on Customer {
  String get displayName {
    final company = companyName?.trim();
    if (company != null && company.isNotEmpty) return company;
    return contactName?.trim() ?? '';
  }
}

/// Listelerde avatar yerine kullanılan baş harfler.
///
/// İKİ harf: tek harf listede çok fazla tekrar ediyor ve kullanıcı
/// satırları birbirinden ayırt edemiyordu ("A" ile başlayan yedi
/// müşteri). Ad boşsa soru işareti döner — hiçbir zaman boş kutu çıkmaz.
String initialsOf(String ad) {
  final temiz = ad.trim();
  if (temiz.isEmpty) return '?';
  final parcalar = temiz.split(RegExp(r'\s+'));
  if (parcalar.length >= 2) {
    return (parcalar[0][0] + parcalar[1][0]).toUpperCase();
  }
  return temiz.length >= 2
      ? temiz.substring(0, 2).toUpperCase()
      : temiz.toUpperCase();
}
