import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/palette.dart';
import '../../app/theme.dart';

import '../../shared/app_version_label.dart';
import '../../shared/brand_footer.dart';
import '../auth/data/session_controller.dart';
import '../calendar/calendar_screen.dart';
import '../finance/finance_screen.dart';
import '../settings/settings_screen.dart';
import '../stock/products_list_screen.dart';
import '../feedback/feedback_screen.dart';
import '../subscription/payments_screen.dart';
import '../subscription/subscription_screen.dart';
import '../sync/data/sync_conflict_repository.dart';
import '../sync/sync_conflicts_screen.dart';

/// "Daha Fazla" — modüller + ayarlara tek giriş.
///
/// Ayar kalemleri (şirket, personel, iş türleri, bildirimler, senkron,
/// güncelleme) burada tek tek listelenmiyor; hepsi [SettingsScreen]
/// altında toplandı. Menü modüllerle ayarları karıştırdıkça uzuyor ve
/// aranan şey kayboluyordu.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Daha Fazla')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (session != null)
            _ProfilBasligi(
              adSoyad: session.fullName,
              sirket: session.companyName,
            ),
          const _GrupBasligi('İşletme'),

          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Takvim'),
            subtitle: const Text('Randevular ve iş planı'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
          ),
          // Teknisyen ve görüntüleyici işletmenin finansal verilerini
          // göremez (bkz. backend RolePermissions).
          if (session?.canSeeFinance ?? false)
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Finans'),
              subtitle: const Text('Gelir, gider, aylık özet'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const FinanceScreen())),
            ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Stok Yönetimi'),
            subtitle: const Text('Ürünler, barkod, stok durumu'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProductsListScreen()),
            ),
          ),
          const _GrupBasligi('Hesap'),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Abonelik'),
            subtitle: const Text('Paketin ve kalan süren'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Ödemelerim'),
            subtitle: const Text('Geçmiş ödemeler, tarih ve tutarlar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PaymentsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.forum_outlined),
            title: const Text('Geri Bildirim'),
            subtitle: const Text('Öneri, sorun ya da soru gönderin'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const FeedbackScreen())),
          ),

          // Çakışma varken görünür — yoksa menüyü kalabalıklaştırmaz.
          Consumer(
            builder: (context, ref, _) {
              final count =
                  ref.watch(localConflictCountProvider).valueOrNull ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return ListTile(
                leading: Icon(Icons.sync_problem_outlined, color: scheme.error),
                title: const Text('Senkron çakışmaları'),
                subtitle: const Text('Hangi halin kalacağını seç'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: scheme.onError,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SyncConflictsScreen(),
                  ),
                ),
              );
            },
          ),

          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Ayarlar'),
            subtitle: const Text('Profil, işletme, bildirim, senkron'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: scheme.error),
            title: Text('Çıkış yap', style: TextStyle(color: scheme.error)),
            onTap: () async {
              await ref.read(sessionControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
          const BrandFooter(),
          const AppVersionLabel(),
        ],
      ),
    );
  }
}

/// Profil başlığı — tasarım teslimatı ekran 10.
///
/// Kullanıcı, şirket ve abonelik durumu bir arada: "Daha Fazla" ekranını
/// açan kullanıcı çoğu zaman "hangi hesaptayım, ne kadar sürem kaldı"
/// sorusuyla geliyor.
class _ProfilBasligi extends StatelessWidget {
  const _ProfilBasligi({required this.adSoyad, required this.sirket});

  final String adSoyad;
  final String sirket;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: palet.accent.withValues(alpha: 0.12),
              borderRadius: AppRadius.card,
            ),
            child: Center(
              child: Text(
                _basHarfler(adSoyad),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: palet.accent),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adSoyad,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  sirket,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _basHarfler(String ad) {
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
}

/// Menü grubu başlığı.
///
/// Gruplama olmadan liste on bir satırlık düz bir yığındı ve kullanıcı
/// aradığını gözüyle taramak zorunda kalıyordu.
class _GrupBasligi extends StatelessWidget {
  const _GrupBasligi(this.metin);

  final String metin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        metin.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.palette.textMuted,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
