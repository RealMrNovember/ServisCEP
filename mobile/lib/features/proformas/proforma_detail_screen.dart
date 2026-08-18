import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/money.dart';
import 'data/proformas_repository.dart';

final _proformaProvider = FutureProvider.family<Proforma?, String>((ref, id) {
  return ref.watch(proformasRepositoryProvider).byId(id);
});

class ProformaDetailScreen extends ConsumerWidget {
  const ProformaDetailScreen({super.key, required this.proformaId});
  final String proformaId;

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
          appBar: AppBar(title: Text(proforma.code)),
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
            ],
          ),
        );
      },
    );
  }
}
