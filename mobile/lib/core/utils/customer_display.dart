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
