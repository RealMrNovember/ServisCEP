import 'package:flutter/material.dart';

import '../../shared/tc_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/palette.dart';
import '../../app/theme.dart';

import '../../shared/app_version_label.dart';
import '../../shared/ui.dart';
import '../../shared/brand_footer.dart';
import '../../core/utils/customer_display.dart';
import '../auth/data/session_controller.dart';
import '../calendar/calendar_screen.dart';
import '../finance/finance_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/sync_status_screen.dart';
import '../stock/barcode_flow.dart';
import '../stock/products_list_screen.dart';
import '../subscription/payments_screen.dart';
import '../subscription/subscription_screen.dart';
import '../../core/sync/sync_status.dart';
import '../subscription/data/subscription_models.dart';
import '../subscription/data/subscription_repository.dart';
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
              abonelik: ref.watch(subscriptionStatusProvider).valueOrNull,
            ),
          const MenuGroupHeader('İşletme'),

          ListTile(
            leading: const TcIcon(TcIcons.calendar),
            title: const Text('Takvim'),
            subtitle: const Text('Randevular ve iş planı'),
            trailing: const TcIcon(TcIcons.chevronRight),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
          ),
          // Teknisyen ve görüntüleyici işletmenin finansal verilerini
          // göremez (bkz. backend RolePermissions).
          if (session?.canSeeFinance ?? false)
            ListTile(
              leading: const TcIcon(TcIcons.wallet),
              title: const Text('Finans'),
              subtitle: const Text('Gelir, gider, aylık özet'),
              trailing: const TcIcon(TcIcons.chevronRight),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const FinanceScreen())),
            ),
          ListTile(
            leading: const TcIcon(TcIcons.box),
            title: const Text('Stok Yönetimi'),
            subtitle: const Text('Ürünler, barkod, stok durumu'),
            trailing: const TcIcon(TcIcons.chevronRight),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProductsListScreen()),
            ),
          ),
          ListTile(
            leading: const TcIcon(TcIcons.barcode),
            title: const Text('Barkod Tara'),
            subtitle: const Text('Ürünü hızlı bul veya ekle'),
            trailing: const TcIcon(TcIcons.chevronRight),
            onTap: () => scanBarcodeAndOpen(context, ref),
          ),
          const MenuGroupHeader('Hesap'),
          ListTile(
            leading: const TcIcon(TcIcons.star),
            title: const Text('Abonelik'),
            subtitle: const Text('Paketin ve kalan süren'),
            trailing: const TcIcon(TcIcons.chevronRight),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
          ),
          ListTile(
            leading: const TcIcon(TcIcons.pdf),
            title: const Text('Ödemelerim'),
            subtitle: const Text('Geçmiş ödemeler, tarih ve tutarlar'),
            trailing: const TcIcon(TcIcons.chevronRight),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PaymentsScreen())),
          ),

          // Çakışma varken görünür — yoksa menüyü kalabalıklaştırmaz.
          Consumer(
            builder: (context, ref, _) {
              final count =
                  ref.watch(localConflictCountProvider).valueOrNull ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return ListTile(
                leading: TcIcon(TcIcons.syncProblem, color: scheme.error),
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
                    const TcIcon(TcIcons.chevronRight),
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

          Consumer(
            builder: (context, ref, _) {
              final bekleyen =
                  ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
              return ListTile(
                leading: TcIcon(bekleyen > 0 ? TcIcons.sync : TcIcons.cloudOk),
                title: const Text('Eşitleme durumu'),
                subtitle: Text(
                  bekleyen > 0
                      ? '$bekleyen kayıt bekliyor'
                      : 'Her şey eşitlendi',
                ),
                trailing: const TcIcon(TcIcons.chevronRight),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
                ),
              );
            },
          ),

          const Divider(height: 24),
          ListTile(
            leading: const TcIcon(TcIcons.settings),
            title: const Text('Ayarlar'),
            subtitle: const Text('Profil, işletme, bildirim, senkron'),
            trailing: const TcIcon(TcIcons.chevronRight),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          ListTile(
            leading: TcIcon(TcIcons.logout, color: scheme.error),
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
  const _ProfilBasligi({
    required this.adSoyad,
    required this.sirket,
    required this.abonelik,
  });

  final String adSoyad;
  final String sirket;

  /// Çevrimdışıyken null gelir — rozet o zaman hiç çizilmez. Yanlış bir
  /// "süresi doldu" göstermektense hiç göstermemek doğru.
  final SubscriptionStatus? abonelik;

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
                initialsOf(adSoyad),
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
                if (_abonelikMetni != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _abonelikRengi(palet).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _abonelikMetni!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _abonelikRengi(palet),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Deneme · 6 gün" / "Pro · 41 gün". Süresiz abonelikte gün yazılmaz.
  String? get _abonelikMetni {
    final a = abonelik;
    if (a == null) return null;
    final ad = a.isTrial ? 'Deneme' : (a.plan?.name ?? 'Abonelik');
    final gun = a.daysRemaining;
    if (gun == null) return ad;
    if (gun <= 0) return '$ad · süresi doldu';
    return '$ad · $gun gün';
  }

  /// Son bir haftaya girildiyse uyarı tonu: kullanıcı bunu görmeli.
  Color _abonelikRengi(AppPalette palet) {
    final gun = abonelik?.daysRemaining;
    if (gun == null) return palet.accent;
    if (gun <= 0) return palet.dangerText;
    return gun <= 7 ? palet.warningText : palet.accent;
  }
}
