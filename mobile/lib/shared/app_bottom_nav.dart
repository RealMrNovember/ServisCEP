import 'package:flutter/material.dart';

import '../app/motion.dart';
import '../app/palette.dart';
import '../app/theme.dart';
import '../app/typography.dart';
import 'tc_icon.dart';

/// Alt gezinme sekmesi.
class AppNavDestination {
  const AppNavDestination({required this.icon, required this.label});

  /// [TcIcons] adı.
  final String icon;
  final String label;
}

/// Kayan alt gezinme çubuğu.
///
/// Tasarım sistemi § 5 çubuğu ekranın alt kenarına yapışık, aktif sekmenin
/// ÜSTÜNDE 3dp aksan çizgisi olan düz bir dikdörtgen olarak tanımlıyor.
/// Burada bilinçli olarak farklı bir yol izleniyor:
///
/// - Çubuk kenardan boşluklu ve yuvarlatılmış duruyor. Uygulamanın geri
///   kalanı 18-24dp yarıçaplı kartlardan oluşuyor; kenara yapışık keskin
///   bir dikdörtgen o dile ait değil.
/// - Aktif sekme, üstündeki çizgi yerine ikonun ARKASINDAKİ yumuşak aksan
///   kapsülüyle belirtiliyor ve bu kapsül sekmeler arasında KAYIYOR. Üst
///   çizgi eski bir sekme kalıbı; kayan kapsül geçişin nereden nereye
///   olduğunu gösterdiği için göz hareketi takip edebiliyor.
/// - Gösterge sabit ölçülü ve yalnızca ikonu sarıyor. İçeriğin tamamını
///   saran bir kapsül denendi; etiket uzunluğu sekmeden sekmeye
///   değiştiği için ("İşler" ile "Müşteriler" yan yana) satır dengesiz
///   görünüyordu.
/// - Etiketler her sekmede açık. Kullanıcı kitlesi simge tahmin etmiyor.
///
/// Çubuğun rengi PALETTEN gelir. Önceki sürümde zemin ve yazı rengi koyu
/// temaya sabitlenmişti; açık temada beyaz ekranın üstünde siyah bir çubuk
/// duruyordu.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onSelect,
  });

  final int currentIndex;
  final List<AppNavDestination> destinations;
  final ValueChanged<int> onSelect;

  /// Göstergenin ölçüleri. Kayan kapsülün konumu bu sabitlerden
  /// hesaplandığı için ikon bloğuyla birebir aynı olmak zorunda.
  static const _gostergeGenisligi = 52.0;
  static const _gostergeYuksekligi = 30.0;

  /// İkon bloğunun üst boşluğu. Gösterge de aynı hizaya yerleştiği için
  /// değer tek yerde tutuluyor.
  static const _ikonUstBosluk = 10.0;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final altBosluk = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        // Sistem çubuğu varsa onun üstünde bir nefes bırakılır; yoksa
        // ekran kenarından sabit boşluk.
        altBosluk > 0 ? altBosluk + AppSpacing.sm : AppSpacing.lg,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // navBg değil surface: çubuk kenara yapışık değil, zeminin
          // ÜSTÜNDE duruyor ve zeminden bir kademe ayrışması gerekiyor.
          color: palet.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: palet.border),
          boxShadow: palet.shadowRaise,
        ),
        child: SizedBox(
          height: AppSize.nav,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: LayoutBuilder(
              builder: (context, kisit) {
                final sekmeGenisligi = kisit.maxWidth / destinations.length;
                final gostergeSol =
                    currentIndex * sekmeGenisligi +
                    (sekmeGenisligi - _gostergeGenisligi) / 2;

                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: AppMotion.base,
                      curve: AppMotion.emphasized,
                      left: gostergeSol,
                      top: _ikonUstBosluk,
                      width: _gostergeGenisligi,
                      height: _gostergeYuksekligi,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: palet.accentSoft,
                          borderRadius: AppRadius.pill,
                          // Hafif ışıma — kapsülü zeminden ayırıyor ama
                          // sahada dikkat dağıtacak kadar değil.
                          boxShadow: [
                            BoxShadow(
                              color: palet.accentGlow,
                              blurRadius: 12,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < destinations.length; i++)
                          Expanded(
                            child: _NavItem(
                              destination: destinations[i],
                              selected: i == currentIndex,
                              onTap: () => onSelect(i),
                              ikonYuksekligi: _gostergeYuksekligi,
                              ustBosluk: _ikonUstBosluk,
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.ikonYuksekligi,
    required this.ustBosluk,
  });

  final AppNavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final double ikonYuksekligi;
  final double ustBosluk;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final renk = selected ? palet.accentText : palet.textMuted;

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(top: ustBosluk),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: ikonYuksekligi,
                child: Center(
                  // Renk geçişi kapsülün kaymasıyla aynı sürede; ikisi
                  // tek bir hareket gibi okunuyor.
                  child: TweenAnimationBuilder<Color?>(
                    duration: AppMotion.base,
                    curve: AppMotion.standard,
                    tween: ColorTween(end: renk),
                    builder: (context, gecisRengi, _) => TcIcon(
                      destination.icon,
                      size: 21,
                      color: gecisRengi ?? renk,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Türkçe etiketler uzun ("Müşteriler") ve beş sekme dar
              // ekranda sıkışıyor; sığmayan etiket kırpılmak yerine
              // küçülür.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedDefaultTextStyle(
                    duration: AppMotion.base,
                    curve: AppMotion.standard,
                    style: AppTypography.navLabel.copyWith(
                      fontSize: 12,
                      color: renk,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                    child: Text(destination.label, maxLines: 1, softWrap: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
