import '../utils/money.dart';

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

  /// Kalemin KDV kipine göre net/KDV/brüt tutarları.
  ///
  /// Hesap [LineAmounts]'a devredilir: form önizlemesi, liste ve PDF aynı
  /// koddan geçmezse er ya da geç farklı rakam gösterirler.
  LineAmounts amounts(VatMode vatMode) => LineAmounts.compute(
    quantity: quantity,
    unitPriceMinor: unitPriceMinor,
    discountMinor: discountMinor,
    vatRate: taxRate,
    vatMode: vatMode,
  );

  DocItemDraft copyWith({
    String? description,
    int? quantity,
    String? unit,
    int? unitPriceMinor,
    int? taxRate,
    int? discountMinor,
  }) {
    return DocItemDraft(
      description: description ?? this.description,
      productId: productId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPriceMinor: unitPriceMinor ?? this.unitPriceMinor,
      taxRate: taxRate ?? this.taxRate,
      discountMinor: discountMinor ?? this.discountMinor,
    );
  }
}
