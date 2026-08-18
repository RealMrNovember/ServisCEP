import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/company_provider.dart';
import '../../core/services/pdf_service.dart';
import '../../core/utils/money.dart';
import '../customers/data/customers_repository.dart';
import 'data/quotes_repository.dart';

const _quoteStatusLabels = {
  'TASLAK': 'Taslak',
  'GONDERILDI': 'Gönderildi',
  'BEKLEMEDE': 'Beklemede',
  'KABUL_EDILDI': 'Kabul Edildi',
  'REDDEDILDI': 'Reddedildi',
  'SURESI_DOLDU': 'Süresi Doldu',
};

final _quoteProvider = FutureProvider.family<Quote?, String>((ref, id) {
  return ref.watch(quotesRepositoryProvider).byId(id);
});

class QuoteDetailScreen extends ConsumerWidget {
  const QuoteDetailScreen({super.key, required this.quoteId});
  final String quoteId;

  Future<void> _changeStatus(BuildContext context, WidgetRef ref, Quote quote) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in _quoteStatusLabels.entries)
              ListTile(
                title: Text(entry.value),
                trailing: quote.status == entry.key ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await ref.read(quotesRepositoryProvider).updateStatus(quote.id, selected);
    }
  }

  Future<void> _sharePdf(BuildContext context, WidgetRef ref, Quote quote) async {
    final company = await ref.read(currentCompanyProvider.future);
    final customer = await ref.read(customersRepositoryProvider).byId(quote.customerId);
    final items = await ref.read(quotesRepositoryProvider).watchItems(quote.id).first;
    if (company == null || customer == null) return;

    final file = await PdfService.buildQuoteOrProformaPdf(
      documentTitle: 'TEKLİF',
      code: quote.code,
      date: quote.createdAt,
      company: company,
      customer: customer,
      items: items.map((i) => i.toLineItem()).toList(),
      notes: quote.notes,
    );
    if (context.mounted) {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Teklif ${quote.code}'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quoteAsync = ref.watch(_quoteProvider(quoteId));

    return quoteAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Hata: $e'))),
      data: (quote) {
        if (quote == null) return const Scaffold(body: Center(child: Text('Teklif bulunamadı')));

        final itemsAsync = ref.watch(quoteItemsProvider(quote.id));

        return Scaffold(
          appBar: AppBar(
            title: Text(quote.code),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'PDF Paylaş',
                onPressed: () => _sharePdf(context, ref, quote),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ActionChip(
                label: Text(_quoteStatusLabels[quote.status] ?? quote.status),
                onPressed: () => _changeStatus(context, ref, quote),
              ),
              const SizedBox(height: 20),
              Text(
                'Kalemler',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              itemsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Hata: $e'),
                data: (items) => Column(
                  children: [
                    for (final item in items)
                      Card(
                        child: ListTile(
                          title: Text(item.description),
                          subtitle: Text(
                            '${item.quantity} ${item.unit} × ${Money.formatMinor(item.unitPriceMinor)}',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (quote.notes?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Text(
                  'Notlar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(quote.notes!),
              ],
              const Divider(height: 32),
              Row(
                children: [
                  Text(
                    'Genel Toplam',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    Money.formatMinor(quote.totalMinor),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _sharePdf(context, ref, quote),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF Oluştur ve Paylaş'),
              ),
            ],
          ),
        );
      },
    );
  }
}
