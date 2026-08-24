import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/doc_item_draft.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/code_generator.dart';
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

  Future<Proforma> create({
    required String companyId,
    required String customerId,
    required List<DocItemDraft> items,
    DateTime? validUntil,
    String? notes,
  }) async {
    final countThisYear = await (_db.select(
      _db.proformas,
    )..where((p) => p.companyId.equals(companyId))).get().then((rows) => rows.length);
    final code = CodeGenerator.next('PRO', countThisYear);
    final id = _uuid.v4();
    final total = items.fold<int>(0, (sum, item) => sum + item.lineTotalMinor);

    await _db.transaction(() async {
      await _db.into(_db.proformas).insert(
        ProformasCompanion.insert(
          id: id,
          companyId: companyId,
          code: code,
          customerId: customerId,
          validUntil: Value(validUntil),
          notes: Value(notes),
          totalMinor: Value(total),
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
