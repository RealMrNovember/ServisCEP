import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/subscription_models.dart';
import '../data/subscription_repository.dart';
import '../subscription_screen.dart';

const _dismissedOnKey = 'subscription_banner_dismissed_on';

/// Banner bugün kapatıldı mı — "yumuşak" kademe (4-7 gün) günde bir kez
/// gösterilir: kullanıcı kapatınca ertesi güne kadar görünmez.
final _bannerDismissedTodayProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  final dismissedOn = await storage.read(key: _dismissedOnKey);
  return dismissedOn == _todayKey();
});

String _todayKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month}-${now.day}';
}

enum _BannerTier { none, soon, urgent, expired }

/// Deneme/abonelik durumu şeridi — docs/01'deki "rahatsız etmeden hatırlat"
/// ilkesiyle kademeli çalışır:
///
///  - 7 günden fazla süre varken HİÇ görünmez (bilgi Abonelik ekranında),
///  - 4-7 gün: günde bir kez, kapatılabilir ince bir bilgi şeridi,
///  - son 3 gün: kompakt ama kalıcı (kapatılamaz) uyarı şeridi,
///  - süre dolduğunda: net bir uyarı kartı.
///
/// Hiçbir kademe modal/popup değildir; dokununca Abonelik ekranı açılır.
/// Çevrimdışıyken veya durum alınamazsa hiçbir şey göstermez (dashboard'ı
/// asla bloke etmez).
class SubscriptionBanner extends ConsumerWidget {
  const SubscriptionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(subscriptionStatusProvider);
    final status = statusAsync.valueOrNull;
    if (status == null) return const SizedBox.shrink();

    final tier = _tierFor(status);
    if (tier == _BannerTier.none) return const SizedBox.shrink();

    if (tier == _BannerTier.soon) {
      final dismissed =
          ref.watch(_bannerDismissedTodayProvider).valueOrNull ?? true;
      if (dismissed) return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: _bannerFor(context, ref, status, tier),
    );
  }

  _BannerTier _tierFor(SubscriptionStatus status) {
    if (!status.hasActiveSubscription) return _BannerTier.expired;

    final days = status.daysRemaining;
    if (days == null) return _BannerTier.none;
    if (days <= 3) return _BannerTier.urgent;
    if (days <= 7) return _BannerTier.soon;
    return _BannerTier.none;
  }

  Widget _bannerFor(
    BuildContext context,
    WidgetRef ref,
    SubscriptionStatus status,
    _BannerTier tier,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final days = status.daysRemaining ?? 0;
    final noun = status.isTrial ? 'Deneme süren' : 'Aboneliğin';

    return switch (tier) {
      _BannerTier.expired => _BannerCard(
        icon: Icons.error_outline_rounded,
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
        title: '$noun sona erdi',
        subtitle: 'Kesintisiz devam etmek için bir paket seç.',
        onTap: () => _openSubscription(context),
      ),
      _BannerTier.urgent => _BannerCard(
        icon: Icons.timer_outlined,
        background: scheme.tertiaryContainer,
        foreground: scheme.onTertiaryContainer,
        title: days == 0
            ? '$noun bugün sona eriyor'
            : '$noun bitmek üzere: $days gün kaldı',
        subtitle: 'Paketini şimdi seç, kesinti yaşama.',
        onTap: () => _openSubscription(context),
      ),
      _BannerTier.soon => _BannerCard(
        icon: Icons.info_outline_rounded,
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
        title: '$noun $days gün sonra doluyor',
        subtitle: 'Paketleri incelemek için dokun.',
        onTap: () => _openSubscription(context),
        onDismiss: () async {
          await ref
              .read(secureStorageProvider)
              .write(key: _dismissedOnKey, value: _todayKey());
          ref.invalidate(_bannerDismissedTodayProvider);
        },
      ),
      _BannerTier.none => const SizedBox.shrink(),
    };
  }

  void _openSubscription(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onDismiss,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Future<void> Function()? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: Icon(Icons.close_rounded, color: foreground, size: 18),
                  onPressed: onDismiss,
                  tooltip: 'Bugünlük kapat',
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: foreground,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
