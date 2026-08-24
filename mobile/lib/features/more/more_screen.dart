import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/app_version_label.dart';
import '../../shared/brand_footer.dart';
import '../auth/data/session_controller.dart';
import '../calendar/calendar_screen.dart';
import '../finance/finance_screen.dart';
import '../settings/company_settings_screen.dart';
import '../settings/job_types_screen.dart';
import '../settings/notification_settings_screen.dart';
import '../stock/products_list_screen.dart';
import '../subscription/subscription_screen.dart';
import '../sync/data/sync_conflict_repository.dart';
import '../sync/sync_conflicts_screen.dart';

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
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                child: Text(
                  session.fullName.isNotEmpty ? session.fullName[0].toUpperCase() : '?',
                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
              title: Text(session.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(session.companyName),
            ),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Takvim'),
            subtitle: const Text('Randevular ve iş planı'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
          ),
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
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProductsListScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Abonelik'),
            subtitle: const Text('Paketin, ödeme bildirimi, geçmiş'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
          ),
          // Çakışma varken görünür — yoksa menüyü kalabalıklaştırmaz.
          Consumer(
            builder: (context, ref, _) {
              final count =
                  ref.watch(localConflictCountProvider).valueOrNull ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return ListTile(
                leading: Icon(
                  Icons.sync_problem_outlined,
                  color: scheme.error,
                ),
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
          ListTile(
            leading: const Icon(Icons.business_outlined),
            title: const Text('Şirket ayarları'),
            subtitle: const Text('Ünvan, işletme türü, IBAN'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CompanySettingsScreen()),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.people_alt_outlined),
            title: Text('Kullanıcılar ve yetkiler'),
            subtitle: Text('Yakında — personel ve rol yönetimi'),
            trailing: Icon(Icons.chevron_right),
            enabled: false,
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('İş türleri'),
            subtitle: const Text('Kendi türlerini ekle'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const JobTypesScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Bildirimler'),
            subtitle: const Text('Hatırlatma süresi ve bildirimler'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),
          const Divider(height: 24),
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
