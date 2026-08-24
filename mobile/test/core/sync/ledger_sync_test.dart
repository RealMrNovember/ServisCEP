import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/core/database/app_database.dart';
import 'package:serviscep/core/network/sync_api_client.dart';
import 'package:serviscep/core/sync/sync_service.dart';
import 'package:serviscep/features/finance/data/finance_repository.dart';

import '../../support/fake_sync_api_client.dart';
import '../../support/fake_token_store.dart';
import '../../support/in_memory_database.dart';

const _companyId = 'company-1';
const _customerId = 'customer-1';

/// Cari hesap senkronu — sunucu tek doğruluk kaynağıdır.
///
/// Bu testlerin koruduğu asıl risk: telefonun iyimser kaydı ile sunucunun
/// kaydının YAN YANA durup bakiyeyi İKİ KEZ saydırması.
void main() {
  late AppDatabase db;
  late FakeSyncApiClient api;

  setUp(() async {
    db = createInMemoryDatabase();
    api = FakeSyncApiClient();
    await db
        .into(db.companies)
        .insert(CompaniesCompanion.insert(id: _companyId, name: 'Test Co'));
    await db
        .into(db.customers)
        .insert(
          CustomersCompanion.insert(
            id: _customerId,
            companyId: _companyId,
            code: 'CUS-1',
            contactName: const Value('Test'),
          ),
        );
  });

  tearDown(() => db.close());

  SyncService buildService() =>
      SyncService(db, api, FakeTokenStore(initialToken: 'test-token'));

  RemoteRecord ledgerRecord({
    required String id,
    required String type,
    required int amount,
    required String referenceType,
    String? referenceId,
  }) => RemoteRecord(
    id: id,
    version: 1,
    raw: {
      'id': id,
      'customer_id': _customerId,
      'entry_date': '2026-08-24T10:00:00.000000Z',
      'type': type,
      'amount_minor': amount,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'description': 'Sunucu kaydı',
    },
  );

  Future<int> balance() async {
    final rows = await (db.select(
      db.customerLedgerEntries,
    )..where((e) => e.customerId.equals(_customerId))).get();
    return rows.fold<int>(
      0,
      (sum, e) => sum + (e.type == 'DEBIT' ? e.amountMinor : -e.amountMinor),
    );
  }

  test('tahsilatın iyimser yerel kaydı, sunucunun kaydıyla DEĞİŞTİRİLİR '
      've bakiye iki kez sayılmaz', () async {
    final repo = FinanceRepository(db);
    await repo.recordPayment(
      companyId: _companyId,
      customerId: _customerId,
      amountMinor: 50000,
    );

    // Yerelde tek bir iyimser CREDIT var.
    var rows = await db.select(db.customerLedgerEntries).get();
    expect(rows, hasLength(1));
    expect(rows.single.syncStatus, 'PENDING');
    expect(await balance(), -50000);

    // Sunucu aynı tahsilat için KENDİ id'siyle kayıt döndürür; referans
    // ödeme kaydının id'sidir (mobil de artık bunu kullanıyor).
    final paymentId = rows.single.referenceId!;
    api.ledgerToPull = [
      ledgerRecord(
        id: 'server-credit',
        type: 'CREDIT',
        amount: 50000,
        referenceType: 'payment',
        referenceId: paymentId,
      ),
    ];

    await buildService().runOnce(_companyId);

    rows = await db.select(db.customerLedgerEntries).get();
    expect(rows, hasLength(1), reason: 'aynı tahsilat iki kez durmamalı');
    expect(rows.single.id, 'server-credit');
    expect(rows.single.syncStatus, 'SYNCED');
    expect(await balance(), -50000, reason: 'bakiye iki kez sayılmamalı');
  });

  test('iş tamamlama borcu da sunucununkiyle değiştirilir', () async {
    await db
        .into(db.customerLedgerEntries)
        .insert(
          CustomerLedgerEntriesCompanion.insert(
            id: 'local-debit',
            companyId: _companyId,
            customerId: _customerId,
            type: 'DEBIT',
            amountMinor: 120000,
            referenceType: 'job',
            referenceId: const Value('job-1'),
            description: 'SRV-1 — Kamera montajı',
          ),
        );

    api.ledgerToPull = [
      ledgerRecord(
        id: 'server-debit',
        type: 'DEBIT',
        amount: 120000,
        referenceType: 'job',
        referenceId: 'job-1',
      ),
    ];

    await buildService().runOnce(_companyId);

    final rows = await db.select(db.customerLedgerEntries).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'server-debit');
    expect(await balance(), 120000);
  });

  test('referansı olmayan (manuel düzeltme) sunucu kaydı yerele eklenir', () async {
    api.ledgerToPull = [
      ledgerRecord(
        id: 'server-adjust',
        type: 'DEBIT',
        amount: 5000,
        referenceType: 'manual_adjustment',
      ),
    ];

    await buildService().runOnce(_companyId);

    final rows = await db.select(db.customerLedgerEntries).get();
    expect(rows, hasLength(1));
    expect(rows.single.referenceType, 'manual_adjustment');
    expect(rows.single.syncStatus, 'SYNCED');
  });

  test('İLİŞKİSİZ bir iyimser kayıt, başka bir olayın pull edilmesiyle '
      'silinmez', () async {
    await db
        .into(db.customerLedgerEntries)
        .insert(
          CustomerLedgerEntriesCompanion.insert(
            id: 'local-other',
            companyId: _companyId,
            customerId: _customerId,
            type: 'DEBIT',
            amountMinor: 999,
            referenceType: 'job',
            referenceId: const Value('BASKA-IS'),
            description: 'Henüz senkronlanmamış başka iş',
          ),
        );

    api.ledgerToPull = [
      ledgerRecord(
        id: 'server-debit',
        type: 'DEBIT',
        amount: 120000,
        referenceType: 'job',
        referenceId: 'job-1',
      ),
    ];

    await buildService().runOnce(_companyId);

    final ids = (await db.select(db.customerLedgerEntries).get())
        .map((e) => e.id)
        .toSet();
    expect(ids, containsAll(['local-other', 'server-debit']));
  });
}
