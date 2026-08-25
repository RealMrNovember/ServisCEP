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
    final query =
        _db.select(_db.quotes).join([
          innerJoin(
            _db.customers,
            _db.customers.id.equalsExp(_db.quotes.customerId),
          ),
        ])
          ..where(_db.quotes.companyId.equals(companyId))
          ..orderBy([OrderingTerm.desc(_db.quotes.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => QuoteWithCustomer(
              r.readTable(_db.quotes),
              r.readTable(_db.customers),
            ),
          )
          .toList(),
    );
  }

  /// Tek teklif — durum değişikliği sonrası detay ekranının kendiliğinden
  /// tazelenmesi için akış olarak izlenir.
  Stream<Quote?> watchById(String id) {
    return (_db.select(
      _db.quotes,
    )..where((q) => q.id.equals(id))).watchSingleOrNull();
  }

  /// Sıradaki belge numarası — son kullanılan numaradan devam eder
  /// (bkz. [DocumentNumbering]).
  Future<String> nextCode(String companyId) async {
    final codes = await (_db.selectOnly(_db.quotes)
          ..addColumns([_db.quotes.code])
          ..where(_db.quotes.companyId.equals(companyId)))
        .map((row) => row.read(_db.quotes.code)!)
        .get();
    return DocumentNumbering.next(
      fallbackPrefix: 'TKF',
      existingCodes: codes,
    );
  }

  /// Numaranın bu işletmede zaten kullanılıp kullanılmadığı — aynı numaralı
  /// iki teklif muhasebe tarafında gerçek bir sorun.
  Future<bool> isCodeTaken(String companyId, String code) async {
    final existing =
        await (_db.select(_db.quotes)..where(
              (q) => q.companyId.equals(companyId) & q.code.equals(code.trim()),
            ))
            .get();
    return existing.isNotEmpty;
  }

  Future<Quote?> byId(String id) {
    return (_db.select(
      _db.quotes,
    )..where((q) => q.id.equals(id))).getSingleOrNull();
  }

  Stream<List<QuoteItem>> watchItems(String quoteId) {
    return (_db.select(
      _db.quoteItems,
    )..where((i) => i.quoteId.equals(quoteId))).watch();
  }

  Future<List<QuoteItem>> itemsOf(String quoteId) {
    return (_db.select(
      _db.quoteItems,
    )..where((i) => i.quoteId.equals(quoteId))).get();
  }

  /// Yeni teklif.
  ///
  /// Belge toplamı burada [LineAmounts] üzerinden hesaplanır ve KDV kipini
  /// hesaba katar; "KDV dahil" bir teklifte kalem fiyatlarının üstüne bir
  /// kez daha KDV eklenmesi, müşteriye yanlış tutarla giden bir belge
  /// demekti.
  Future<Quote> create({
    required String companyId,
    required String customerId,
    required List<DocItemDraft> items,
    String? notes,
    String? introText,
    String? paymentTerms,
    String? deliveryTime,
    String? warrantyTerms,
    Currency currency = Currency.try_,
    VatMode vatMode = VatMode.excluded,
    int vatRate = 20,
    DateTime? validUntil,
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
      await _db
          .into(_db.quotes)
          .insert(
            QuotesCompanion.insert(
              id: id,
              companyId: companyId,
              code: code,
              customerId: customerId,
              notes: Value(notes),
              introText: Value(introText),
              paymentTerms: Value(paymentTerms),
              deliveryTime: Value(deliveryTime),
              warrantyTerms: Value(warrantyTerms),
              totalMinor: Value(total),
              currency: Value(currency.code),
              vatMode: Value(vatMode.code),
              vatRate: Value(vatRate),
              validUntil: Value(validUntil),
            ),
          );

      final itemPayloads = <Map<String, dynamic>>[];
      for (final item in items) {
        final itemId = _uuid.v4();
        await _db
            .into(_db.quoteItems)
            .insert(
              QuoteItemsCompanion.insert(
                id: itemId,
                quoteId: id,
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

      await _enqueue(
        entityId: id,
        operation: 'CREATE',
        payload: {
          'id': id,
          'code': code,
          'customer_id': customerId,
          'notes': notes,
          'intro_text': introText,
          'payment_terms': paymentTerms,
          'delivery_time': deliveryTime,
          'warranty_terms': warrantyTerms,
          'currency': currency.code,
          'vat_mode': vatMode.code,
          'vat_rate': vatRate,
          'valid_until': validUntil?.toIso8601String(),
          'items': itemPayloads,
        },
      );
    });

    return (await byId(id))!;
  }

  Future<void> updateStatus(String id, String status) async {
    await _db.transaction(() async {
      final quote = await (_db.select(
        _db.quotes,
      )..where((q) => q.id.equals(id))).getSingle();
      await (_db.update(_db.quotes)..where((q) => q.id.equals(id))).write(
        QuotesCompanion(
          status: Value(status),
          syncStatus: const Value('PENDING'),
        ),
      );
      await _enqueue(
        entityId: id,
        operation: 'UPDATE',
        baseVersion: quote.version,
        payload: {'status': status},
      );
    });
  }

  Future<void> _enqueue({
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    int? baseVersion,
  }) {
    return _db
        .into(_db.syncOperations)
        .insert(
          SyncOperationsCompanion.insert(
            id: _uuid.v4(),
            entityType: 'quote',
            entityId: entityId,
            operation: operation,
            payload: jsonEncode(payload),
            baseVersion: Value(baseVersion),
          ),
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

final quoteItemsProvider = StreamProvider.family<List<QuoteItem>, String>((
  ref,
  quoteId,
) {
  return ref.watch(quotesRepositoryProvider).watchItems(quoteId);
});

final quoteByIdProvider = StreamProvider.family<Quote?, String>((ref, id) {
  return ref.watch(quotesRepositoryProvider).watchById(id);
});
