import 'package:flutter/material.dart';

import '../app/palette.dart';
import '../app/theme.dart';
import '../app/typography.dart';
import 'tc_icon.dart';

/// Buton varyantı — tasarım sistemi § 5.
enum AppButtonVariant {
  /// Ekran başına BİR tane. Dolgu rengi accentSolid.
  primary,

  /// Yüzey dolgusu + güçlü kenarlık.
  secondary,

  /// Silme gibi geri dönüşü olmayan eylemler.
  ///
  /// Asla dolu kırmızı değildir: dolu kırmızı buton, dikkat çekmek yerine
  /// kullanıcıyı korkutuyor ve yanlışlıkla basılma oranını artırıyor.
  danger,
}

/// Taşmayan buton.
///
/// Türkçe etiketler İngilizceden %20-30 uzun ("Oluştur ve Gönder",
/// "Kaydet ve Tamamla") ve yanlarına 20dp spinner girince dar ekranlarda
/// ya da büyük yazı tipi ölçeğinde metin butondan taşıyor.
///
/// Burada taşma yapısal olarak imkânsız: etiket [Flexible] içinde satır
/// genişliğini zorlamıyor, [FittedBox] `scaleDown` ile sığmadığında metni
/// kırpmak yerine küçültüyor. Buton tam genişlikte ve iç boşluğu 20dp
/// olduğu için gerçek etiketlerde küçülme fark edilmeyecek kadar az kalır;
/// aşırı yazı tipi ölçeğinde ise metin okunur biçimde küçülür, taşmaz.
///
/// Yükleme sırasında etiket KORUNUR. Tasarım sistemi metni "…" ile
/// değiştirmeyi öneriyor; bunun sebebi taşmayı önlemekti, taşma burada
/// zaten çözüldüğü için kullanıcıdan bilgi saklamaya gerek kalmıyor.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.variant = AppButtonVariant.primary,
    this.expand = true,
  });

  final String label;

  /// null ise buton devre dışıdır. [loading] sırasında da tıklanmaz.
  final VoidCallback? onPressed;

  /// [TcIcons] adı. Yükleme sırasında yerini spinner alır.
  final String? icon;

  final bool loading;
  final AppButtonVariant variant;

  /// Satırın tamamını kaplasın mı.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final etkin = onPressed != null && !loading;

    final (zemin, yaziRengi, kenarlik) = switch (variant) {
      AppButtonVariant.primary => (
        etkin ? palet.accentSolid : palet.disabledBg,
        etkin ? palet.onAccent : palet.disabledText,
        null,
      ),
      AppButtonVariant.secondary => (
        etkin ? palet.surface : palet.disabledBg,
        etkin ? palet.text : palet.disabledText,
        etkin ? palet.borderStrong : palet.disabledBorder,
      ),
      AppButtonVariant.danger => (
        etkin ? palet.dangerSoft : palet.disabledBg,
        etkin ? palet.dangerText : palet.disabledText,
        etkin ? palet.dangerLine : palet.disabledBorder,
      ),
    };

    final yukseklik = variant == AppButtonVariant.primary
        ? AppSize.btnPrimary
        : AppSize.btnSecondary;

    final govde = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: yaziRengi,
            ),
          )
        else if (icon != null)
          TcIcon(icon!, size: 20, color: yaziRengi),
        if (loading || icon != null) const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: AppTypography.bodyStrong.copyWith(
                fontWeight: FontWeight.w700,
                color: yaziRengi,
              ),
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: etkin,
      label: loading ? '$label — işleniyor' : label,
      child: SizedBox(
        height: yukseklik,
        width: expand ? double.infinity : null,
        child: Material(
          color: zemin,
          borderRadius: AppRadius.field,
          child: InkWell(
            onTap: etkin ? onPressed : null,
            borderRadius: AppRadius.field,
            splashColor: palet.pressOverlay,
            highlightColor: palet.pressOverlay,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              decoration: BoxDecoration(
                borderRadius: AppRadius.field,
                border: kenarlik == null ? null : Border.all(color: kenarlik),
              ),
              child: Center(child: govde),
            ),
          ),
        ),
      ),
    );
  }
}
