import 'package:flutter/material.dart';

import '../app/palette.dart';
import '../app/theme.dart';
import 'tc_icon.dart';

/// Adım göstergesi — tasarım teslimatı ekran 05-08 ve 18.
///
/// Adımlar tek satırda: kullanıcı nerede olduğunu ve kaç adım kaldığını
/// her an görüyor. Tamamlanan adımlar geri dönülebilir; ileri adıma
/// dokunarak atlanamaz çünkü sonraki adım öncekinin verisine dayanıyor.
class StepIndicator extends StatelessWidget {
  const StepIndicator({
    super.key,
    required this.etiketler,
    required this.adim,
    required this.hataliAdimlar,
    required this.onGit,
  });

  /// Sıfır tabanlı geçerli adım.
  final int adim;

  /// Doğrulamadan geçmemiş adımlar — daireleri tehlike rengine döner.
  final Set<int> hataliAdimlar;

  final ValueChanged<int> onGit;

  /// Adım adları — soldan sağa.
  final List<String> etiketler;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          for (var i = 0; i < etiketler.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  color: i <= adim ? palet.accent : palet.border,
                ),
              ),
            _AdimDairesi(
              sira: i,
              etiket: etiketler[i],
              gecerli: i == adim,
              tamamlandi: i < adim,
              hatali: hataliAdimlar.contains(i),
              // Yalnızca GERİYE dokunulabiliyor: ileri adım öncekinin
              // verisine dayanıyor ve atlanırsa boş form gösterilirdi.
              onTap: i < adim ? () => onGit(i) : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _AdimDairesi extends StatelessWidget {
  const _AdimDairesi({
    required this.sira,
    required this.etiket,
    required this.gecerli,
    required this.tamamlandi,
    required this.hatali,
    this.onTap,
  });

  final int sira;
  final String etiket;
  final bool gecerli;
  final bool tamamlandi;
  final bool hatali;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    final renk = hatali
        ? palet.dangerText
        : (gecerli || tamamlandi ? palet.accent : palet.textMuted);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gecerli || hatali
                    ? renk.withValues(alpha: 0.16)
                    : Colors.transparent,
                border: Border.all(color: renk, width: 1.4),
              ),
              child: Center(
                child: tamamlandi && !hatali
                    ? TcIcon(TcIcons.check, size: 14, color: renk)
                    : Text(
                        '${sira + 1}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: renk,
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              etiket,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: renk, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
