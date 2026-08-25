import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/theme.dart';
import '../core/services/pdf_service.dart';
import '../core/utils/customer_display.dart';
import '../core/utils/money.dart';
import '../features/customers/data/customers_repository.dart';
import 'document_items_editor.dart';
import 'ui.dart';

final _dateFormat = DateFormat('d MMMM y', 'tr_TR');

/// Teklif ve proforma detayının ortak gövdesi.
///
/// İki belge aynı bilgileri gösterir; ayrı yazıldıklarında biri
/// güncellenip diğeri geride kalıyordu. Farklılıkları ([statusPill],
/// [onChangeStatus]) parametre olarak alınır.
class DocumentDetailScaffold extends ConsumerWidget {
  const DocumentDetailScaffold({
    super.key,
    required this.code,
    required this.customerId,
    required this.createdAt,
    required this.items,
    required this.currency,
    required this.vatMode,
    required this.vatRate,
    required this.onShare,
    this.validUntil,
    this.notes,
    this.statusPill,
    this.onChangeStatus,
    this.shareLabel = 'PDF oluştur ve gönder',
  });

  final String code;
  final String customerId;
  final DateTime createdAt;
  final DateTime? validUntil;
  final String? notes;

  final AsyncValue<List<PdfLineItem>> items;
  final Currency currency;
  final VatMode vatMode;
  final int vatRate;

  final Widget? statusPill;
  final VoidCallback? onChangeStatus;
  final VoidCallback onShare;
  final String shareLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final customerAsync = ref.watch(customerByIdProvider(customerId));
    final expired = validUntil != null && validUntil!.isBefore(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(code),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'PDF gönder',
            onPressed: onShare,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (statusPill != null)
                onChangeStatus == null
                    ? statusPill!
                    : GestureDetector(
                        onTap: onChangeStatus,
                        child: statusPill!,
                      ),
              StatusPill(
                label: currency.code,
                color: scheme.onSurfaceVariant,
                dense: true,
              ),
              StatusPill(
                label: vatMode.label,
                color: scheme.onSurfaceVariant,
                dense: true,
              ),
              if (expired)
                const StatusPill(
                  label: 'Süresi doldu',
                  color: AppColors.warning,
                  dense: true,
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
          customerAsync.maybeWhen(
            data: (customer) => customer == null
                ? const SizedBox.shrink()
                : AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MÜŞTERİ',
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          customer.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (customer.phone?.trim().isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              customer.phone!.trim(),
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),

          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              children: [
                InfoRowTile(
                  label: 'Düzenlenme',
                  value: _dateFormat.format(createdAt),
                  icon: Icons.event_outlined,
                ),
                InfoRowTile(
                  label: 'Geçerlilik',
                  value: validUntil == null
                      ? 'Belirtilmedi'
                      : _dateFormat.format(validUntil!),
                  icon: Icons.schedule_outlined,
                ),
                InfoRowTile(
                  label: 'KDV oranı',
                  value: '%$vatRate',
                  icon: Icons.percent_outlined,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader('Kalemler'),
          items.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Kalemler okunamadı: $e'),
            data: (lines) {
              final amounts = lines
                  .map((line) => line.amounts(vatMode))
                  .toList();

              return Column(
                children: [
                  for (var i = 0; i < lines.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lines[i].description,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${lines[i].quantity} ${lines[i].unit} × '
                                    '${Money.formatMinor(lines[i].unitPriceMinor, currency: currency)}'
                                    '  ·  KDV %${lines[i].taxRate}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Money.formatMinor(
                                amounts[i].grossMinor,
                                currency: currency,
                              ),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  DocumentTotalsCard(
                    totals: DocumentTotals.from(amounts),
                    currency: currency,
                    vatMode: vatMode,
                  ),
                ],
              );
            },
          ),

          if (notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader('Notlar'),
            AppCard(child: Text(notes!.trim())),
          ],

          const SizedBox(height: AppSpacing.xxl),
          FilledButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(shareLabel),
          ),
          if (onChangeStatus != null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onChangeStatus,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Durumu değiştir'),
            ),
          ],
        ],
      ),
    );
  }
}
