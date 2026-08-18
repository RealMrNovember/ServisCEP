/// Teklif/Proforma kalemi taslağı — kaydedilmeden önce bellekte tutulur.
/// Bkz. docs/03 § Proforma Modülü, § Teklif Modülü ve docs/16 § Teklif /
/// Proforma Kalem Seçimi.
class DocItemDraft {
  DocItemDraft({
    required this.description,
    this.productId,
    this.quantity = 1,
    this.unit = 'adet',
    this.unitPriceMinor = 0,
    this.taxRate = 20,
    this.discountMinor = 0,
  });

  final String? productId;
  String description;
  int quantity;
  String unit;
  int unitPriceMinor;
  int taxRate;
  int discountMinor;

  int get lineTotalMinor {
    final subtotal = quantity * unitPriceMinor - discountMinor;
    final withTax = subtotal + (subtotal * taxRate / 100).round();
    return withTax < 0 ? 0 : withTax;
  }
}
