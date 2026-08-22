import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/core/database/app_database.dart';
import 'package:serviscep/features/customers/data/customers_repository.dart';

import '../../support/in_memory_database.dart';

const _companyId = 'company-1';

void main() {
  late AppDatabase db;
  late CustomersRepository repo;

  setUp(() async {
    db = createInMemoryDatabase();
    repo = CustomersRepository(db);
    await db
        .into(db.companies)
        .insert(CompaniesCompanion.insert(id: _companyId, name: 'Test Co'));
  });

  tearDown(() => db.close());

  test('create hem müşteriyi yazar hem CREATE outbox satırı düşer', () async {
    final customer = await repo.create(
      companyId: _companyId,
      contactName: 'Ahmet Yılmaz',
      type: 'BIREYSEL',
    );

    final ops = await db.select(db.syncOperations).get();
    expect(ops, hasLength(1));
    expect(ops.single.entityType, 'customer');
    expect(ops.single.entityId, customer.id);
    expect(ops.single.operation, 'CREATE');
    final payload = jsonDecode(ops.single.payload) as Map<String, dynamic>;
    expect(payload['id'], customer.id);
    expect(payload['contact_name'], 'Ahmet Yılmaz');
  });

  test(
    'update, çağıranın gördüğü version\'ı base_version olarak kuyruklar',
    () async {
      final customer = await repo.create(
        companyId: _companyId,
        contactName: 'Ahmet Yılmaz',
        type: 'BIREYSEL',
      );
      // create sonrası outbox'ta 1 satır var; onu temizleyip update'e bakalım.
      await db.delete(db.syncOperations).go();

      await repo.update(customer.copyWith(notes: const Value('Güncellendi')));

      final op = await db.select(db.syncOperations).getSingle();
      expect(op.operation, 'UPDATE');
      expect(op.baseVersion, customer.version);
      final payload = jsonDecode(op.payload) as Map<String, dynamic>;
      expect(payload['notes'], 'Güncellendi');
    },
  );

  test(
    'softDelete DELETE outbox satırı düşer ve yerelde deletedAt set edilir',
    () async {
      final customer = await repo.create(
        companyId: _companyId,
        contactName: 'Ahmet Yılmaz',
        type: 'BIREYSEL',
      );
      await db.delete(db.syncOperations).go();

      await repo.softDelete(customer.id);

      final updated = await repo.byId(customer.id);
      expect(updated!.deletedAt, isNotNull);
      final op = await db.select(db.syncOperations).getSingle();
      expect(op.operation, 'DELETE');
      expect(op.entityId, customer.id);
    },
  );
}
