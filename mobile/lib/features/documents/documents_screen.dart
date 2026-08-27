import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/palette.dart';
import '../../app/typography.dart';

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
            // Sayı sekmede: kullanıcı hangi sekmede ne kadar iş
            // olduğunu açmadan görebilmeli.
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
            return _BelgeSatiri(
              kod: item.quote.code,
              musteri: item.customer.displayName,
              durum: item.quote.status,
              tutarMinor: item.quote.totalMinor,
              tarih: item.quote.createdAt,
              bekliyor: item.quote.syncStatus == 'PENDING',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => QuoteDetailScreen(quoteId: item.quote.id),
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
            return _BelgeSatiri(
              kod: item.proforma.code,
              musteri: item.customer.displayName,
              tutarMinor: item.proforma.totalMinor,
              tarih: item.proforma.createdAt,
              bekliyor: item.proforma.syncStatus == 'PENDING',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ProformaDetailScreen(proformaId: item.proforma.id),
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

/// Belge satırı — tasarım teslimatı ekran 08.
///
/// Belge KODU en üstte ve tek aralıklı: kullanıcı belgeleri müşteriden
/// değil koddan arıyor ("0091'i gönderdim mi?"). Müşteri adı ikinci
/// satırda, durum ve tutar sağda.
class _BelgeSatiri extends StatelessWidget {
  const _BelgeSatiri({
    required this.kod,
    required this.musteri,
    this.durum,
    required this.tutarMinor,
    required this.tarih,
    required this.bekliyor,
    required this.onTap,
  });

  final String kod;
  final String musteri;

  /// Proformada durum alanı YOK — o yüzden isteğe bağlı; null ise rozet
  /// çizilmiyor.
  final String? durum;

  final int tutarMinor;
  final DateTime? tarih;
  final bool bekliyor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return AppCard(
      pending: bekliyor,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kod, style: AppTypography.mono.copyWith(fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  musteri,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    if (durum != null) _BelgeDurumu(durum: durum!),
                    if (tarih != null) ...[
                      if (durum != null) const SizedBox(width: AppSpacing.sm),
                      Text(
                        DateFormat('d MMM', 'tr_TR').format(tarih!),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            Money.formatMinor(tutarMinor, decimals: false),
            style: AppTypography.monoLarge.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

/// Belge durum rozeti.
///
/// "Süresi doldu" ve "Reddedildi" uyarı/tehlike tonunda: bunlar
/// kullanıcının EYLEM alması gereken durumlar, geri kalanı bilgi.
class _BelgeDurumu extends StatelessWidget {
  const _BelgeDurumu({required this.durum});

  final String durum;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final (metin, renk) = switch (durum) {
      'KABUL_EDILDI' => ('Onaylandı', palet.successText),
      'REDDEDILDI' => ('Reddedildi', palet.dangerText),
      'SURESI_DOLDU' => ('Süresi doldu', palet.warningText),
      'GONDERILDI' => ('Gönderildi', palet.accent),
      'BEKLEMEDE' => ('Beklemede', palet.warningText),
      _ => ('Taslak', palet.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        metin,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: renk, fontSize: 11),
      ),
    );
  }
}
