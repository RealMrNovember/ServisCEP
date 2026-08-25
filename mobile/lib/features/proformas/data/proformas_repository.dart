import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/doc_item_draft.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/document_numbering.dart';
import '../../../core/utils/money.dart';
import '../../auth/data/session_controller.dart';

class ProformaWithCustomer {
  ProformaWithCustomer(this.proforma, this.customer);
  final Proforma proforma;
  final Customer customer;
}

/// Proforma modülü — bkz. docs/03 § Proforma Modülü.
class ProformasRepository {
  ProformasRepository(this._db);
  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<ProformaWithCustomer>> watchAll(String companyId) {
    final query = _db.select(_db.proformas).join([
      innerJoin(_db.customers, _db.customers.id.equalsExp(_db.proformas.customerId)),
    ])
      ..where(_db.proformas.companyId.equals(companyId))
      ..orderBy([OrderingTerm.desc(_db.proformas.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map((r) => ProformaWithCustomer(r.readTable(_db.proformas), r.readTable(_db.customers)))
          .toList(),
    );
  }

  Future<Proforma?> byId(String id) {
    return (_db.select(_db.proformas)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Stream<List<ProformaItem>> watchItems(String proformaId) {
    return (_db.select(_db.proformaItems)..where((i) => i.proformaId.equals(proformaId))).watch();
  }

  /// Yeni proforma. Toplam, KDV kipini hesaba katan ortak hesap motoruyla
  /// bulunur (bkz. core/utils/money.dart) — teklifle aynı kod yolundan
  /// geçmesi, iki belgenin aynı kalemler için farklı tutar göstermesini
  /// engeller.
  /// Sıradaki belge numarası — bkz. [DocumentNumbering].
  Future<String> nextCode(String companyId) async {
    final codes = await (_db.selectOnly(_db.proformas)
          ..addColumns([_db.proformas.code])
          ..where(_db.proformas.companyId.equals(companyId)))
        .map((row) => row.read(_db.proformas.code)!)
        .get();
    return DocumentNumbering.next(
      fallbackPrefix: 'PRF',
      existingCodes: codes,
    );
  }

  Future<bool> isCodeTaken(String companyId, String code) async {
    final existing =
        await (_db.select(_db.proformas)..where(
              (p) => p.companyId.equals(companyId) & p.code.equals(code.trim()),
            ))
            .get();
    return existing.isNotEmpty;
  }

  Stream<Proforma?> watchById(String id) {
    return (_db.select(
      _db.proformas,
    )..where((p) => p.id.equals(id))).watchSingleOrNull();
  }

  Future<List<ProformaItem>> itemsOf(String proformaId) {
    return (_db.select(
      _db.proformaItems,
    )..where((i) => i.proformaId.equals(proformaId))).get();
  }

  Future<Proforma> create({
    required String companyId,
    required String customerId,
    required List<DocItemDraft> items,
    DateTime? validUntil,
    String? notes,
    String? introText,
    String? paymentTerms,
    String? deliveryTime,
    String? warrantyTerms,
    Currency currency = Currency.try_,
    VatMode vatMode = VatMode.excluded,
    int vatRate = 20,
    String? requestedCode,
  }) async {
    final code = requestedCode?.trim().isNotEmpty == true
        ? requestedCode!.trim()
        : await nextCode(companyId);
    final id = _uuid.v4();
    final total = DocumentTotals.from(
      items.map((item) => item.amounts(vatMode)),
    ).grossMinor;

    await _db.transaction(() async {
      await _db.into(_db.proformas).insert(
        ProformasCompanion.insert(
          id: id,
          companyId: companyId,
          code: code,
          customerId: customerId,
          validUntil: Value(validUntil),
          notes: Value(notes),
          introText: Value(introText),
          paymentTerms: Value(paymentTerms),
          deliveryTime: Value(deliveryTime),
          warrantyTerms: Value(warrantyTerms),
          totalMinor: Value(total),
          currency: Value(currency.code),
          vatMode: Value(vatMode.code),
          vatRate: Value(vatRate),
        ),
      );
      final itemPayloads = <Map<String, dynamic>>[];
      for (final item in items) {
        final itemId = _uuid.v4();
        await _db.into(_db.proformaItems).insert(
          ProformaItemsCompanion.insert(
            id: itemId,
            proformaId: id,
            description: item.description,
            quantity: Value(item.quantity),
            unit: Value(item.unit),
            unitPriceMinor: Value(item.unitPriceMinor),
            taxRate: Value(item.taxRate),
            discountMinor: Value(item.discountMinor),
          ),
        );
        itemPayloads.add({
          'id': itemId,
          'description': item.description,
          'quantity': item.quantity,
          'unit': item.unit,
          'unit_price_minor': item.unitPriceMinor,
          'tax_rate': item.taxRate,
          'discount_minor': item.discountMinor,
        });
      }
      await _db.into(_db.syncOperations).insert(
        SyncOperationsCompanion.insert(
          id: _uuid.v4(),
          entityType: 'proforma',
          entityId: id,
          operation: 'CREATE',
          payload: jsonEncode({
            'id': id,
            'code': code,
            'customer_id': customerId,
            'valid_until': validUntil?.toIso8601String(),
            'notes': notes,
            'intro_text': introText,
            'payment_terms': paymentTerms,
            'delivery_time': deliveryTime,
            'warranty_terms': warrantyTerms,
            'currency': currency.code,
            'vat_mode': vatMode.code,
            'vat_rate': vatRate,
            'items': itemPayloads,
          }),
        ),
      );
    });

    return (await byId(id))!;
  }
}

final proformasRepositoryProvider = Provider<ProformasRepository>((ref) {
  return ProformasRepository(ref.watch(databaseProvider));
});

final proformasListProvider = StreamProvider<List<ProformaWithCustomer>>((ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  if (session == null) return const Stream.empty();
  return ref.watch(proformasRepositoryProvider).watchAll(session.companyId);
});

final proformaItemsProvider = StreamProvider.family<List<ProformaItem>, String>((ref, proformaId) {
  return ref.watch(proformasRepositoryProvider).watchItems(proformaId);
});

final proformaByIdProvider = StreamProvider.family<Proforma?, String>((
  ref,
  id,
) {
  return ref.watch(proformasRepositoryProvider).watchById(id);
});
