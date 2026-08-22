import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/core_providers.dart';

/// Cari hesap sorguları — bkz. docs/15-cari-hesap.md.
class CustomerLedgerRepository {
  CustomerLedgerRepository(this._db);
  final AppDatabase _db;

  Stream<List<CustomerLedgerEntry>> watchEntries(String customerId) {
    return (_db.select(_db.customerLedgerEntries)
          ..where((e) => e.customerId.equals(customerId))
          ..orderBy([(e) => OrderingTerm.desc(e.entryDate)]))
        .watch();
  }

  /// Bakiye = SUM(DEBIT) - SUM(CREDIT) — kaynak doğruluk her zaman bu
  /// tablodur, hiçbir yerde ayrıca cache'lenmez (bkz. docs/15 § Bakiye
  /// Hesaplama).
  Stream<int> watchBalance(String customerId) {
    return watchEntries(customerId).map((entries) {
      var balance = 0;
      for (final e in entries) {
        balance += e.type == 'DEBIT' ? e.amountMinor : -e.amountMinor;
      }
      return balance;
    });
  }
}

final customerLedgerRepositoryProvider = Provider<CustomerLedgerRepository>((
  ref,
) {
  return CustomerLedgerRepository(ref.watch(databaseProvider));
});

final customerBalanceProvider = StreamProvider.family<int, String>((
  ref,
  customerId,
) {
  return ref.watch(customerLedgerRepositoryProvider).watchBalance(customerId);
});

final customerLedgerEntriesProvider =
    StreamProvider.family<List<CustomerLedgerEntry>, String>((ref, customerId) {
      return ref
          .watch(customerLedgerRepositoryProvider)
          .watchEntries(customerId);
    });
