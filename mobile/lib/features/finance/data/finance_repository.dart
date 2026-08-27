import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/data/session_controller.dart';

/// Bir ayın gelir/gider toplamı — grafikte bir sütun.
class AyOzeti {
  const AyOzeti({
    required this.ay,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  /// Ayın ilk günü.
  final DateTime ay;
  final int incomeMinor;
  final int expenseMinor;

  int get netMinor => incomeMinor - expenseMinor;
}

/// Finans özet ekranının tüm verisi.
///
/// Tek bir modelde toplanıyor: ekran dört ayrı sorgu izlediğinde
/// parçalar farklı anlarda geliyor ve kullanıcı sayıların birbiri
/// ardına yerine oturmasını izliyordu.
class FinansGorunumu {
  const FinansGorunumu({required this.aylar, required this.receivableMinor});

  /// Eskiden yeniye, son 6 ay. Sonuncusu içinde bulunulan ay.
  final List<AyOzeti> aylar;

  /// Müşterilerden olan toplam alacak (cari borç − tahsilat).
  final int receivableMinor;

  AyOzeti get buAy => aylar.last;

  AyOzeti? get gecenAy => aylar.length >= 2 ? aylar[aylar.length - 2] : null;

  /// Net kârın geçen aya göre yüzde değişimi.
  ///
  /// Geçen ay sıfır ya da negatifse null döner: "%∞ artış" ya da eksi
  /// bir tabana bölünmüş bir oran kullanıcıya hiçbir şey anlatmıyor.
  double? get netDegisimYuzdesi {
    final onceki = gecenAy?.netMinor ?? 0;
    if (onceki <= 0) return null;
    return (buAy.netMinor - onceki) / onceki * 100;
  }
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

  /// Son 6 ayın gelir/gider serisi + toplam alacak.
  ///
  /// Tek seferde altı ay okunuyor ve gruplama bellekte yapılıyor: aylık
  /// altı ayrı sorgu açmak, aynı tabloyu altı kez taramak demekti.
  Stream<FinansGorunumu> watchOverview(String companyId) {
    final simdi = DateTime.now();
    final buAyBasi = DateTime(simdi.year, simdi.month);
    final baslangic = DateTime(simdi.year, simdi.month - 5);
    final bitis = DateTime(simdi.year, simdi.month + 1);

    final gelirler =
        (_db.select(_db.incomeEntries)..where(
              (i) =>
                  i.companyId.equals(companyId) &
                  i.date.isBiggerOrEqualValue(baslangic) &
                  i.date.isSmallerThanValue(bitis),
            ))
            .watch();

    return gelirler.asyncMap((incomes) async {
      final expenses =
          await (_db.select(_db.expenseEntries)..where(
                (e) =>
                    e.companyId.equals(companyId) &
                    e.date.isBiggerOrEqualValue(baslangic) &
                    e.date.isSmallerThanValue(bitis),
              ))
              .get();

      final ledger = await (_db.select(
        _db.customerLedgerEntries,
      )..where((l) => l.companyId.equals(companyId))).get();

      final gelirToplam = <DateTime, int>{};
      final giderToplam = <DateTime, int>{};
      for (final i in incomes) {
        final anahtar = DateTime(i.date.year, i.date.month);
        gelirToplam[anahtar] = (gelirToplam[anahtar] ?? 0) + i.amountMinor;
      }
      for (final e in expenses) {
        final anahtar = DateTime(e.date.year, e.date.month);
        giderToplam[anahtar] = (giderToplam[anahtar] ?? 0) + e.amountMinor;
      }

      // Kaydı olmayan ay atlanmıyor, sıfır olarak konuyor: grafikte
      // eksik sütun, o ayın hiç olmadığı izlenimi veriyordu.
      final aylar = <AyOzeti>[];
      for (var geri = 5; geri >= 0; geri--) {
        final ay = DateTime(buAyBasi.year, buAyBasi.month - geri);
        aylar.add(
          AyOzeti(
            ay: ay,
            incomeMinor: gelirToplam[ay] ?? 0,
            expenseMinor: giderToplam[ay] ?? 0,
          ),
        );
      }

      var alacak = 0;
      for (final l in ledger) {
        alacak += l.type == 'DEBIT' ? l.amountMinor : -l.amountMinor;
      }

      return FinansGorunumu(
        aylar: aylar,
        // Müşteriler net alacaklıysa (fazla ödeme) alacak sıfır gösterilir;
        // eksi bir "alacak" rakamı okunmuyor.
        receivableMinor: alacak < 0 ? 0 : alacak,
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
      await _db
          .into(_db.incomeEntries)
          .insert(
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
      await _db
          .into(_db.expenseEntries)
          .insert(
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
      await _db
          .into(_db.payments)
          .insert(
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

      await _db
          .into(_db.customerLedgerEntries)
          .insert(
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
    return _db
        .into(_db.syncOperations)
        .insert(
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

final financeOverviewProvider = StreamProvider<FinansGorunumu>((ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  if (session == null) return const Stream.empty();
  return ref.watch(financeRepositoryProvider).watchOverview(session.companyId);
});
