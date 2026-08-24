import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/data/session_controller.dart';

class MonthlySummary {
  const MonthlySummary({required this.incomeMinor, required this.expenseMinor});
  final int incomeMinor;
  final int expenseMinor;
  int get netMinor => incomeMinor - expenseMinor;
}

/// Finans modülü — bkz. docs/04 § Gelir Modülü, § Gider Modülü, § Finans
/// Dashboard, § Tahsilat Modülü (docs/03).
class FinanceRepository {
  FinanceRepository(this._db);
  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<IncomeEntry>> watchIncome(String companyId) {
    return (_db.select(_db.incomeEntries)
          ..where((i) => i.companyId.equals(companyId))
          ..orderBy([(i) => OrderingTerm.desc(i.date)]))
        .watch();
  }

  Stream<List<ExpenseEntry>> watchExpenses(String companyId) {
    return (_db.select(_db.expenseEntries)
          ..where((e) => e.companyId.equals(companyId))
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .watch();
  }

  Stream<MonthlySummary> watchThisMonthSummary(String companyId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);

    final incomeStream = (_db.select(_db.incomeEntries)..where(
          (i) =>
              i.companyId.equals(companyId) &
              i.date.isBiggerOrEqualValue(start) &
              i.date.isSmallerThanValue(end),
        ))
        .watch();
    final expenseStream = (_db.select(_db.expenseEntries)..where(
          (e) =>
              e.companyId.equals(companyId) &
              e.date.isBiggerOrEqualValue(start) &
              e.date.isSmallerThanValue(end),
        ))
        .watch();

    return incomeStream.asyncMap((incomes) async {
      final expenses = await expenseStream.first;
      return MonthlySummary(
        incomeMinor: incomes.fold<int>(0, (sum, i) => sum + i.amountMinor),
        expenseMinor: expenses.fold<int>(0, (sum, e) => sum + e.amountMinor),
      );
    });
  }

  Future<void> addIncome({
    required String companyId,
    required String description,
    required int amountMinor,
    required String category,
    String? customerId,
    String? method,
    String? note,
  }) async {
    final id = _uuid.v4();
    await _db.transaction(() async {
      await _db.into(_db.incomeEntries).insert(
        IncomeEntriesCompanion.insert(
          id: id,
          companyId: companyId,
          description: description,
          amountMinor: amountMinor,
          category: Value(category),
          customerId: Value(customerId),
          method: Value(method ?? 'Nakit'),
          note: Value(note),
        ),
      );
      await _enqueue(
        entityType: 'income_entry',
        entityId: id,
        payload: {
          'id': id,
          'description': description,
          'customer_id': customerId,
          'category': category,
          'amount_minor': amountMinor,
          'method': method ?? 'Nakit',
          'note': note,
        },
      );
    });
  }

  Future<void> addExpense({
    required String companyId,
    required String description,
    required int amountMinor,
    required String category,
    String? vendorName,
    String? method,
    String? note,
  }) async {
    final id = _uuid.v4();
    await _db.transaction(() async {
      await _db.into(_db.expenseEntries).insert(
        ExpenseEntriesCompanion.insert(
          id: id,
          companyId: companyId,
          description: description,
          amountMinor: amountMinor,
          category: Value(category),
          vendorName: Value(vendorName),
          method: Value(method ?? 'Nakit'),
          note: Value(note),
        ),
      );
      await _enqueue(
        entityType: 'expense_entry',
        entityId: id,
        payload: {
          'id': id,
          'description': description,
          'category': category,
          'amount_minor': amountMinor,
          'vendor_name': vendorName,
          'method': method ?? 'Nakit',
          'note': note,
        },
      );
    });
  }

  /// Tahsilat kaydı + cari hesaba ALACAK düşümü — tek transaction (bkz.
  /// docs/07 § Transaction Kuralı, docs/15 § Otomatik Kayıt Oluşturma).
  ///
  /// Senkron notu: yalnızca payment kaydı push edilir — backend, kendi
  /// idempotent ALACAK cari kaydını tahsilatı alırken kendisi oluşturur
  /// (cari hareketler iki tarafta bağımsız hesaplanır, bkz. ROADMAP § B10
  /// bilinçli kapsam sınırları).
  Future<void> recordPayment({
    required String companyId,
    required String customerId,
    required int amountMinor,
    String? jobId,
    String? method,
    String? note,
  }) async {
    final id = _uuid.v4();
    await _db.transaction(() async {
      await _db.into(_db.payments).insert(
        PaymentsCompanion.insert(
          id: id,
          companyId: companyId,
          customerId: customerId,
          jobId: Value(jobId),
          amountMinor: amountMinor,
          method: Value(method ?? 'Nakit'),
          note: Value(note),
        ),
      );

      await _db.into(_db.customerLedgerEntries).insert(
        CustomerLedgerEntriesCompanion.insert(
          id: _uuid.v4(),
          companyId: companyId,
          customerId: customerId,
          type: 'CREDIT',
          amountMinor: amountMinor,
          referenceType: 'payment',
          // Referans TAHSİLATIN kendisidir (işin değil). Önceden buraya
          // jobId yazılıyordu; sunucu ise payment.id yazıyor. Bu uyumsuzluk
          // yüzünden senkronda aynı tahsilatın yerel ve sunucu kaydı
          // eşleştirilemez, bakiye çift sayılırdı.
          referenceId: Value(id),
          description: note?.isNotEmpty == true ? note! : 'Tahsilat',
        ),
      );

      await _enqueue(
        entityType: 'payment',
        entityId: id,
        payload: {
          'id': id,
          // URL yolu için gerekli (POST /customers/{id}/payments) — istek
          // gövdesine girmez, sync_service gönderirken ayıklar.
          'customer_id': customerId,
          'job_id': jobId,
          'amount_minor': amountMinor,
          'method': method ?? 'Nakit',
          'note': note,
        },
      );
    });
  }

  Future<void> _enqueue({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) {
    return _db.into(_db.syncOperations).insert(
      SyncOperationsCompanion.insert(
        id: _uuid.v4(),
        entityType: entityType,
        entityId: entityId,
        operation: 'CREATE',
        payload: jsonEncode(payload),
      ),
    );
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(databaseProvider));
});

final incomeListProvider = StreamProvider<List<IncomeEntry>>((ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  if (session == null) return const Stream.empty();
  return ref.watch(financeRepositoryProvider).watchIncome(session.companyId);
});

final expenseListProvider = StreamProvider<List<ExpenseEntry>>((ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  if (session == null) return const Stream.empty();
  return ref.watch(financeRepositoryProvider).watchExpenses(session.companyId);
});

final monthlySummaryProvider = StreamProvider<MonthlySummary>((ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  if (session == null) return const Stream.empty();
  return ref.watch(financeRepositoryProvider).watchThisMonthSummary(session.companyId);
});
