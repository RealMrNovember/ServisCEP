import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/utils/customer_display.dart';
import '../../core/utils/money.dart';
import '../../shared/skeleton.dart';
import '../../shared/sync_indicators.dart';
import '../../shared/ui.dart';
import '../proformas/data/proformas_repository.dart';
import '../proformas/proforma_detail_screen.dart';
import '../proformas/proforma_form_screen.dart';
import '../quotes/data/quotes_repository.dart';
import '../quotes/quote_detail_screen.dart';
import '../quotes/quote_form_screen.dart';

const _quoteStatusLabels = {
  'TASLAK': 'Taslak',
  'GONDERILDI': 'Gönderildi',
  'BEKLEMEDE': 'Beklemede',
  'KABUL_EDILDI': 'Kabul Edildi',
  'REDDEDILDI': 'Reddedildi',
  'SURESI_DOLDU': 'Süresi Doldu',
};

/// Belge Merkezi — bkz. docs/03 § Belge Merkezi.
///
/// NOT: Servis formu/fatura/tahsilat belgeleri ve PDF üretimi sonraki
/// oturumda eklenecek (bkz. ROADMAP.md — M11). Şu an Teklif ve Proforma
/// listeleri gerçek veriyle çalışıyor.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isQuotesTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Belgeler'),
        actions: const [
          PendingBadge(),
          SizedBox(width: AppSpacing.md),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Teklifler'),
            Tab(text: 'Proformalar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_QuotesTab(), _ProformasTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (isQuotesTab) {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const QuoteFormScreen()));
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProformaFormScreen()),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: Text(isQuotesTab ? 'Yeni Teklif' : 'Yeni Proforma'),
      ),
    );
  }
}

class _QuotesTab extends ConsumerWidget {
  const _QuotesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotesAsync = ref.watch(quotesListProvider);

    return quotesAsync.when(
      loading: () => const AppSkeleton(count: 5),
      error: (_, _) => AppErrorState(
        message: 'Teklifler yüklenemedi.',
        onRetry: () => ref.invalidate(quotesListProvider),
      ),
      data: (quotes) {
        if (quotes.isEmpty) {
          return _EmptyDocsState(
            icon: Icons.description_outlined,
            text: 'Henüz teklif yok',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          itemCount: quotes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = quotes[index];
            return Card(
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuoteDetailScreen(quoteId: item.quote.id),
                  ),
                ),
                title: Text(
                  item.customer.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${item.quote.code} · ${Money.formatMinor(item.quote.totalMinor)}',
                ),
                trailing: Chip(
                  label: Text(
                    _quoteStatusLabels[item.quote.status] ?? item.quote.status,
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ProformasTab extends ConsumerWidget {
  const _ProformasTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proformasAsync = ref.watch(proformasListProvider);

    return proformasAsync.when(
      loading: () => const AppSkeleton(count: 5),
      error: (_, _) => AppErrorState(
        message: 'Proformalar yüklenemedi.',
        onRetry: () => ref.invalidate(proformasListProvider),
      ),
      data: (proformas) {
        if (proformas.isEmpty) {
          return _EmptyDocsState(
            icon: Icons.receipt_long_outlined,
            text: 'Henüz proforma yok',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          itemCount: proformas.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = proformas[index];
            return Card(
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ProformaDetailScreen(proformaId: item.proforma.id),
                  ),
                ),
                title: Text(
                  item.customer.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${item.proforma.code} · ${Money.formatMinor(item.proforma.totalMinor)}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyDocsState extends StatelessWidget {
  const _EmptyDocsState({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
