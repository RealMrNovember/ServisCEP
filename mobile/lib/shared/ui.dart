import 'package:flutter/material.dart';

import '../app/palette.dart';
import '../app/theme.dart';
import '../app/typography.dart';
import 'tc_icon.dart';

/// Ekranlar arası tutarlı, yeniden kullanılabilir parçalar.
///
/// Her ekranın kendi başlık/boş durum/rozet düzenini uydurması, uygulamanın
/// derli toplu görünmemesinin başlıca sebebiydi; ortak parçalar burada.

/// Bölüm başlığı — form ve ayar ekranlarında grupları ayırır.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Kart görünümlü grup kutusu — form bölümlerini görsel olarak toplar.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.accent = false,
    this.pending = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Marka rengiyle vurgulanmış kart (özet/toplam kutuları için).
  final bool accent;

  /// Kayıt cihaza yazıldı ama sunucuya gönderilmedi.
  ///
  /// Sol kenara 3dp uyarı çubuğu koyar. Tasarım sistemi § 6.3:
  /// **eşitlenmiş kayda hiçbir işaret konmaz**, yalnızca bekleyen
  /// işaretlenir. Her karta "eşitlendi" rozeti basmak, gerçekten
  /// bekleyeni görünmez kılıyor.
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    final decorated = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: accent ? palet.accentSoft : palet.surface,
        borderRadius: AppRadius.card,
        border: Border(
          top: BorderSide(color: accent ? palet.accentLine : palet.border),
          right: BorderSide(color: accent ? palet.accentLine : palet.border),
          bottom: BorderSide(color: accent ? palet.accentLine : palet.border),
          left: pending
              ? BorderSide(color: palet.warning, width: 3)
              : BorderSide(color: accent ? palet.accentLine : palet.border),
        ),
        boxShadow: palet.shadowCard,
      ),
      child: child,
    );

    if (onTap == null) return decorated;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: onTap,
        child: decorated,
      ),
    );
  }
}

/// Durum rozeti — iş durumu, belge durumu, rol vb.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = color ?? scheme.primary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: AppRadius.pill,
        border: Border.all(color: base.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: base),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: base,
            ),
          ),
        ],
      ),
    );
  }
}

/// Boş durum — liste ekranlarında "hiç kayıt yok" yerine yol gösterir.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: scheme.primary),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Hata durumu — boş durumla AYNI ŞEY DEĞİLDİR.
///
/// Tasarım sistemi § 6.4 ikisini kesin ayırıyor:
///
/// - Boş durum "henüz yok" der; birincil eylemi İLERİdir ("Yeni İş Oluştur").
/// - Hata durumu "bir şey ters gitti" der; birincil eylemi TEKRARdır.
///
/// İkisi aynı göründüğünde kullanıcı sunucuya ulaşılamadığını "kaydım yok"
/// sanıyor. Bu ekran ayrıca cihazdaki verinin güvende olduğunu söylemek
/// ZORUNDADIR — offline-first bir uygulamada asıl korku budur.
///
/// Teknik hata kodu kullanıcıya gösterilmez.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.title = 'Bir şey ters gitti',
    this.message,
    required this.onRetry,
    this.onContinueOffline,
  });

  final String title;

  /// Kullanıcının anlayacağı açıklama. Teknik kod veya yığın izi DEĞİL.
  final String? message;

  final VoidCallback onRetry;

  /// Çevrimdışı devam etme seçeneği. Verilirse ikincil metin butonu çıkar.
  final VoidCallback? onContinueOffline;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl + AppSpacing.xs),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: palet.dangerSoft,
                borderRadius: AppRadius.dialog,
                border: Border.all(color: palet.dangerLine),
              ),
              child: Center(
                child: TcIcon(
                  TcIcons.alertCircle,
                  size: 38,
                  color: palet.dangerText,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.h2.copyWith(color: palet.text),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: palet.textMuted),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            // Zorunlu cümle: cihazdaki veri güvende.
            Text(
              'Cihazdaki kayıtların güvende — hiçbiri kaybolmadı.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: palet.textFaint),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const TcIcon(TcIcons.refresh, size: 20),
                label: const Text('Tekrar Dene'),
              ),
            ),
            if (onContinueOffline != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: onContinueOffline,
                child: const Text('Çevrimdışı devam et'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Etiket + değer satırı — detay ekranlarında bilgi listelemek için.
class InfoRowTile extends StatelessWidget {
  const InfoRowTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
