import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/palette.dart';
import '../../core/database/app_database.dart';
import '../../core/services/document_share.dart';
import '../../core/services/pdf_service.dart';
import '../../core/utils/money.dart';
import '../../shared/document_detail.dart';
import '../../shared/ui.dart';
import '../auth/data/session_controller.dart';
import '../customers/data/customers_repository.dart';
import '../settings/data/company_repository.dart';
import 'data/quotes_repository.dart';

const _quoteStatusLabels = {
  'TASLAK': 'Taslak',
  'GONDERILDI': 'Gönderildi',
  'BEKLEMEDE': 'Beklemede',
  'KABUL_EDILDI': 'Kabul Edildi',
  'REDDEDILDI': 'Reddedildi',
  'SURESI_DOLDU': 'Süresi Doldu',
};

/// Rozet rengi.
///
/// Dolgu tonu (`success`) değil YAZI tonu (`successText`) kullanılıyor:
/// rozet, rengi hem yazıda hem %12 zeminde kullanıyor ve dolgu tonu
/// bu zeminin üstünde AA kontrastını tutturmuyor.
Color _statusColor(String status, AppPalette palet) => switch (status) {
  'KABUL_EDILDI' => palet.successText,
  'REDDEDILDI' => palet.dangerText,
  'SURESI_DOLDU' => palet.warningText,
  'GONDERILDI' => palet.accent,
  _ => palet.textMuted,
};

final _dateFormat = DateFormat('d MMMM y', 'tr_TR');

class QuoteDetailScreen extends ConsumerWidget {
  const QuoteDetailScreen({super.key, required this.quoteId});
  final String quoteId;

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    Quote quote,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in _quoteStatusLabels.entries)
              ListTile(
                title: Text(entry.value),
                trailing: quote.status == entry.key
                    ? const Icon(Icons.check)
                    : null,
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

  Future<void> _sharePdf(
    BuildContext context,
    WidgetRef ref,
    Quote quote,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final company = await ref.read(currentCompanyProvider.future);
    final customer = await ref
        .read(customersRepositoryProvider)
        .byId(quote.customerId);
    final items = await ref.read(quotesRepositoryProvider).itemsOf(quote.id);

    if (company == null || customer == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Firma veya müşteri bilgisi bulunamadı.')),
      );
      return;
    }

    final currency = Currency.fromCode(quote.currency);
    final file = await PdfService.buildQuoteOrProformaPdf(
      documentTitle: 'Teklif Formu',
      code: quote.code,
      date: quote.createdAt,
      company: company,
      customer: customer,
      items: items.map((i) => i.toLineItem()).toList(),
      notes: quote.notes,
      introText: quote.introText,
      paymentTerms: quote.paymentTerms,
      deliveryTime: quote.deliveryTime,
      warrantyTerms: quote.warrantyTerms,
      preparedBy: ref.read(sessionControllerProvider).valueOrNull?.fullName,
      validUntil: quote.validUntil,
      currency: currency,
      vatMode: VatMode.fromCode(quote.vatMode),
      vatRate: quote.vatRate,
    );

    if (!context.mounted) return;
    final validity = quote.validUntil == null
        ? ''
        : '\nGeçerlilik: ${_dateFormat.format(quote.validUntil!)}';
    await showDocumentShareSheet(
      context,
      file: file,
      title: 'Teklif Formu ${quote.code}',
      shareText:
          '${company.name} — Teklif ${quote.code}\n'
          'Toplam: ${Money.formatMinor(quote.totalMinor, currency: currency)}'
          '$validity',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palet = context.palette;

    return ref
        .watch(quoteByIdProvider(quoteId))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('Hata: $e'))),
          data: (quote) {
            if (quote == null) {
              return const Scaffold(
                body: Center(child: Text('Teklif bulunamadı')),
              );
            }

            return DocumentDetailScaffold(
              kindLabel: 'Teklif',
              code: quote.code,
              customerId: quote.customerId,
              createdAt: quote.createdAt,
              validUntil: quote.validUntil,
              notes: quote.notes,
              currency: Currency.fromCode(quote.currency),
              vatMode: VatMode.fromCode(quote.vatMode),
              vatRate: quote.vatRate,
              items: ref
                  .watch(quoteItemsProvider(quote.id))
                  .whenData(
                    (items) => items.map((i) => i.toLineItem()).toList(),
                  ),
              statusPill: StatusPill(
                label: _quoteStatusLabels[quote.status] ?? quote.status,
                color: _statusColor(quote.status, palet),
                icon: Icons.expand_more,
              ),
              onChangeStatus: () => _changeStatus(context, ref, quote),
              onShare: () => _sharePdf(context, ref, quote),
            );
          },
        );
  }
}
