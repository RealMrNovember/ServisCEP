import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/palette.dart';

import '../../app/theme.dart';
import '../../core/constants/customer_types.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/customer_display.dart';
import '../../shared/skeleton.dart';
import '../../shared/sync_indicators.dart';
import '../../shared/ui.dart';
import 'data/customers_repository.dart';

class CustomersListScreen extends ConsumerStatefulWidget {
  const CustomersListScreen({super.key});

  @override
  ConsumerState<CustomersListScreen> createState() =>
      _CustomersListScreenState();
}

class _CustomersListScreenState extends ConsumerState<CustomersListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersListProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        // Kayıt sayısı başlığın altında: kullanıcı listeyi süzerken kaç
        // kayıt arasında gezindiğini bilmeli.
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Müşteriler'),
            customersAsync.maybeWhen(
              data: (m) => Text(
                '${m.length} kayıt',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.palette.textMuted,
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: const [
          PendingBadge(),
          SizedBox(width: AppSpacing.md),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Müşteri ara...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: customersAsync.when(
              loading: () => const AppSkeleton(count: 6),
              error: (_, _) => AppErrorState(
                message: 'Müşteri listesi yüklenemedi.',
                onRetry: () => ref.invalidate(customersListProvider),
              ),
              data: (customers) {
                final filtered = _query.isEmpty
                    ? customers
                    : customers
                          .where(
                            (c) =>
                                c.displayName.toLowerCase().contains(_query) ||
                                (c.phone ?? '').contains(_query),
                          )
                          .toList();

                if (customers.isEmpty) {
                  return _EmptyState(
                    onAdd: () => context.push('/customers/new'),
                  );
                }
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'Sonuç bulunamadı',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _CustomerTile(customer: filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/customers/new'),
        icon: const Icon(Icons.add),
        label: const Text('Yeni Müşteri'),
      ),
    );
  }
}

/// Müşteri satırı — tasarım teslimatı ekran 09.
///
/// Baş harfler İKİ harf: tek harf listede çok fazla tekrar ediyor ve
/// kullanıcı satırları birbirinden ayırt edemiyordu ("A" ile başlayan
/// yedi müşteri).
///
/// NOT: tasarımda satırın sağında cari bakiye var. Bakiye liste
/// sorgusunda yok ve her satır için ayrı sorgu açmak listeyi yavaşlatır;
/// eklenene kadar müşteri türü rozeti duruyor (bkz. ROADMAP).
class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final bekliyor = customer.syncStatus == 'PENDING';

    return AppCard(
      pending: bekliyor,
      onTap: () => context.push('/customers/${customer.id}'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palet.accent.withValues(alpha: 0.12),
              borderRadius: AppRadius.field,
            ),
            child: Center(
              child: Text(
                _basHarfler(customer.displayName),
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: palet.accent),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _altSatir(customer),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: palet.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: palet.border),
            ),
            child: Text(
              customerTypeLabels[customer.type] ?? customer.type,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palet.textMuted,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// İki kelimeli adlarda her kelimenin ilk harfi, tek kelimede ilk iki
  /// harf. Boşsa soru işareti — hiçbir zaman boş kutu görünmüyor.
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

  /// "0216 412 88 90 · Ümraniye" — telefon yoksa müşteri kodu.
  static String _altSatir(Customer c) {
    final telefon = (c.phone ?? '').trim();
    final ilce = (c.ilce ?? '').trim();
    final sol = telefon.isEmpty ? c.code : telefon;
    return ilce.isEmpty ? sol : '$sol · $ilce';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 56,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz müşterin yok',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk müşterini ekleyerek başla.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Müşteri Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}
