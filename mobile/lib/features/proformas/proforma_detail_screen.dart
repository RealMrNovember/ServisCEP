import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/company_provider.dart';
import '../../core/services/pdf_service.dart';
import '../../core/utils/money.dart';
import '../customers/data/customers_repository.dart';
import 'data/proformas_repository.dart';

final _proformaProvider = FutureProvider.family<Proforma?, String>((ref, id) {
  return ref.watch(proformasRepositoryProvider).byId(id);
});

class ProformaDetailScreen extends ConsumerWidget {
  const ProformaDetailScreen({super.key, required this.proformaId});
  final String proformaId;

  Future<void> _sharePdf(BuildContext context, WidgetRef ref, Proforma proforma) async {
    final company = await ref.read(currentCompanyProvider.future);
    final customer = await ref.read(customersRepositoryProvider).byId(proforma.customerId);
    final items = await ref.read(proformasRepositoryProvider).watchItems(proforma.id).first;
    if (company == null || customer == null) return;

    final file = await PdfService.buildQuoteOrProformaPdf(
      documentTitle: 'PROFORMA',
      code: proforma.code,
      date: proforma.createdAt,
      company: company,
      customer: customer,
      items: items.map((i) => i.toLineItem()).toList(),
      notes: proforma.notes,
      validUntil: proforma.validUntil,
    );
    if (context.mounted) {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Proforma ${proforma.code}'),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proformaAsync = ref.watch(_proformaProvider(proformaId));

    return proformaAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Hata: $e'))),
      data: (proforma) {
        if (proforma == null) {
          return const Scaffold(body: Center(child: Text('Proforma bulunamadı')));
        }

        final itemsAsync = ref.watch(proformaItemsProvider(proforma.id));

        return Scaffold(
          appBar: AppBar(
            title: Text(proforma.code),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'PDF Paylaş',
                onPressed: () => _sharePdf(context, ref, proforma),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (proforma.validUntil != null)
                Text(
                  'Geçerlilik: ${DateFormat('d MMMM y', 'tr_TR').format(proforma.validUntil!)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const SizedBox(height: 16),
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
              if (proforma.notes?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Text(
                  'Notlar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(proforma.notes!),
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
                    Money.formatMinor(proforma.totalMinor),
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _sharePdf(context, ref, proforma),
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
