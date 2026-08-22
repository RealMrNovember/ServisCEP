import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/core/database/app_database.dart';
import 'package:serviscep/features/jobs/data/jobs_repository.dart';

import '../../support/in_memory_database.dart';

const _companyId = 'company-1';
const _customerId = 'customer-1';

void main() {
  late AppDatabase db;
  late JobsRepository repo;

  setUp(() async {
    db = createInMemoryDatabase();
    repo = JobsRepository(db);
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
            contactName: const Value('Test Müşteri'),
          ),
        );
  });

  tearDown(() => db.close());

  test('create hem işi yazar hem CREATE outbox satırı düşer', () async {
    final job = await repo.create(
      companyId: _companyId,
      customerId: _customerId,
      title: 'Klima bakımı',
      priority: 'NORMAL',
    );

    final op = await db.select(db.syncOperations).getSingle();
    expect(op.entityType, 'job');
    expect(op.entityId, job.id);
    expect(op.operation, 'CREATE');
    final payload = jsonDecode(op.payload) as Map<String, dynamic>;
    expect(payload['customer_id'], _customerId);
    expect(payload['status'], 'TALEP');
  });

  test(
    'completeWithPrice yerel BORÇ kaydı oluşturur ve TEK bir UPDATE kuyruklar',
    () async {
      final job = await repo.create(
        companyId: _companyId,
        customerId: _customerId,
        title: 'Klima bakımı',
        priority: 'NORMAL',
      );
      await db.delete(db.syncOperations).go();

      await repo.completeWithPrice(job, 50000);

      final ledgerEntries = await db.select(db.customerLedgerEntries).get();
      expect(ledgerEntries, hasLength(1));
      expect(ledgerEntries.single.type, 'DEBIT');
      expect(ledgerEntries.single.amountMinor, 50000);

      // Cari hesap kaydı senkron kuyruğuna GİRMEMELİ — backend kendi BORÇ
      // kaydını idempotent olarak zaten oluşturuyor (bkz. JobsRepository
      // docblock'u).
      final ops = await db.select(db.syncOperations).get();
      expect(ops, hasLength(1));
      expect(ops.single.entityType, 'job');
      expect(ops.single.operation, 'UPDATE');
      final payload = jsonDecode(ops.single.payload) as Map<String, dynamic>;
      expect(payload['status'], 'TAMAMLANDI');
      expect(payload['actual_price_minor'], 50000);
    },
  );
}
