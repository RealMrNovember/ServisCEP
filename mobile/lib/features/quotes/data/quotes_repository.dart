import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/doc_item_draft.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/code_generator.dart';
import '../../auth/data/session_controller.dart';

class QuoteWithCustomer {
  QuoteWithCustomer(this.quote, this.customer);
  final Quote quote;
  final Customer customer;
}

/// Teklif modülü — bkz. docs/03 § Teklif Modülü.
class QuotesRepository {
  QuotesRepository(this._db);
  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<QuoteWithCustomer>> watchAll(String companyId) {
    final query = _db.select(_db.quotes).join([
      innerJoin(_db.customers, _db.customers.id.equalsExp(_db.quotes.customerId)),
    ])
      ..where(_db.quotes.companyId.equals(companyId))
      ..orderBy([OrderingTerm.desc(_db.quotes.createdAt)]);

    return query.watch().map(
      (rows) =>
          rows.map((r) => QuoteWithCustomer(r.readTable(_db.quotes), r.readTable(_db.customers))).toList(),
    );
  }

  Future<Quote?> byId(String id) {
    return (_db.select(_db.quotes)..where((q) => q.id.equals(id))).getSingleOrNull();
  }

  Stream<List<QuoteItem>> watchItems(String quoteId) {
    return (_db.select(_db.quoteItems)..where((i) => i.quoteId.equals(quoteId))).watch();
  }

  Future<Quote> create({
    required String companyId,
    required String customerId,
    required List<DocItemDraft> items,
    String? notes,
  }) async {
    final countThisYear = await (_db.select(
      _db.quotes,
    )..where((q) => q.companyId.equals(companyId))).get().then((rows) => rows.length);
    final code = CodeGenerator.next('QTE', countThisYear);
    final id = _uuid.v4();
    final total = items.fold<int>(0, (sum, item) => sum + item.lineTotalMinor);

    await _db.transaction(() async {
      await _db.into(_db.quotes).insert(
        QuotesCompanion.insert(
          id: id,
          companyId: companyId,
          code: code,
          customerId: customerId,
          notes: Value(notes),
          totalMinor: Value(total),
        ),
      );
      for (final item in items) {
        await _db.into(_db.quoteItems).insert(
          QuoteItemsCompanion.insert(
            id: _uuid.v4(),
            quoteId: id,
            description: item.description,
            quantity: Value(item.quantity),
            unit: Value(item.unit),
            unitPriceMinor: Value(item.unitPriceMinor),
            taxRate: Value(item.taxRate),
            discountMinor: Value(item.discountMinor),
          ),
        );
      }
    });

    return (await byId(id))!;
  }

  Future<void> updateStatus(String id, String status) {
    return (_db.update(_db.quotes)..where((q) => q.id.equals(id))).write(
      QuotesCompanion(status: Value(status)),
    );
  }
}

final quotesRepositoryProvider = Provider<QuotesRepository>((ref) {
  return QuotesRepository(ref.watch(databaseProvider));
});

final quotesListProvider = StreamProvider<List<QuoteWithCustomer>>((ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  if (session == null) return const Stream.empty();
  return ref.watch(quotesRepositoryProvider).watchAll(session.companyId);
});

final quoteItemsProvider = StreamProvider.family<List<QuoteItem>, String>((ref, quoteId) {
  return ref.watch(quotesRepositoryProvider).watchItems(quoteId);
});
