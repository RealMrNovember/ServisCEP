import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/services/document_share.dart';
import '../../core/services/pdf_service.dart';
import '../../core/utils/money.dart';
import '../../shared/document_detail.dart';
import '../auth/data/session_controller.dart';
import '../customers/data/customers_repository.dart';
import '../settings/data/company_repository.dart';
import 'data/proformas_repository.dart';

final _dateFormat = DateFormat('d MMMM y', 'tr_TR');

class ProformaDetailScreen extends ConsumerWidget {
  const ProformaDetailScreen({super.key, required this.proformaId});
  final String proformaId;

  Future<void> _sharePdf(
    BuildContext context,
    WidgetRef ref,
    Proforma proforma,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final company = await ref.read(currentCompanyProvider.future);
    final customer = await ref
        .read(customersRepositoryProvider)
        .byId(proforma.customerId);
    final items = await ref
        .read(proformasRepositoryProvider)
        .itemsOf(proforma.id);

    if (company == null || customer == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Firma veya müşteri bilgisi bulunamadı.')),
      );
      return;
    }

    final currency = Currency.fromCode(proforma.currency);
    final file = await PdfService.buildQuoteOrProformaPdf(
      documentTitle: 'Proforma Fatura',
      code: proforma.code,
      date: proforma.createdAt,
      company: company,
      customer: customer,
      items: items.map((i) => i.toLineItem()).toList(),
      notes: proforma.notes,
      introText: proforma.introText,
      paymentTerms: proforma.paymentTerms,
      deliveryTime: proforma.deliveryTime,
      warrantyTerms: proforma.warrantyTerms,
      preparedBy: ref.read(sessionControllerProvider).valueOrNull?.fullName,
      validUntil: proforma.validUntil,
      currency: currency,
      vatMode: VatMode.fromCode(proforma.vatMode),
      vatRate: proforma.vatRate,
    );

    if (!context.mounted) return;
    final validity = proforma.validUntil == null
        ? ''
        : '\nGeçerlilik: ${_dateFormat.format(proforma.validUntil!)}';
    await showDocumentShareSheet(
      context,
      file: file,
      title: 'Proforma ${proforma.code}',
      shareText:
          '${company.name} — Proforma ${proforma.code}\n'
          'Toplam: ${Money.formatMinor(proforma.totalMinor, currency: currency)}'
          '$validity',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(proformaByIdProvider(proformaId))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('Hata: $e'))),
          data: (proforma) {
            if (proforma == null) {
              return const Scaffold(
                body: Center(child: Text('Proforma bulunamadı')),
              );
            }

            return DocumentDetailScaffold(
              kindLabel: 'Proforma',
              code: proforma.code,
              customerId: proforma.customerId,
              createdAt: proforma.createdAt,
              validUntil: proforma.validUntil,
              notes: proforma.notes,
              currency: Currency.fromCode(proforma.currency),
              vatMode: VatMode.fromCode(proforma.vatMode),
              vatRate: proforma.vatRate,
              items: ref
                  .watch(proformaItemsProvider(proforma.id))
                  .whenData(
                    (items) => items.map((i) => i.toLineItem()).toList(),
                  ),
              onShare: () => _sharePdf(context, ref, proforma),
            );
          },
        );
  }
}
