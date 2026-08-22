import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/core/database/app_database.dart';
import 'package:serviscep/core/network/api_client.dart';
import 'package:serviscep/core/network/sync_api_client.dart';
import 'package:serviscep/core/sync/sync_service.dart';

import '../../support/fake_sync_api_client.dart';
import '../../support/fake_token_store.dart';
import '../../support/in_memory_database.dart';

const _companyId = 'company-1';

void main() {
  late AppDatabase db;
  late FakeSyncApiClient api;

  setUp(() async {
    db = createInMemoryDatabase();
    api = FakeSyncApiClient();
    await db
        .into(db.companies)
        .insert(CompaniesCompanion.insert(id: _companyId, name: 'Test Co'));
  });

  tearDown(() => db.close());

  SyncService buildService({String? token = 'test-token'}) =>
      SyncService(db, api, FakeTokenStore(initialToken: token));

  Future<void> insertCustomer({
    required String id,
    int version = 1,
    String syncStatus = 'PENDING',
  }) {
    return db
        .into(db.customers)
        .insert(
          CustomersCompanion.insert(
            id: id,
            companyId: _companyId,
            code: 'CUS-1',
            contactName: const Value('Test Müşteri'),
            version: Value(version),
            syncStatus: Value(syncStatus),
          ),
        );
  }

  Future<void> enqueueCustomerOp({
    required String entityId,
    required String operation,
    int? baseVersion,
  }) {
    return db
        .into(db.syncOperations)
        .insert(
          SyncOperationsCompanion.insert(
            id: 'op-$entityId-$operation',
            entityType: 'customer',
            entityId: entityId,
            operation: operation,
            payload:
                '{"id":"$entityId","code":"CUS-1","contact_name":"Test Müşteri","type":"BIREYSEL"}',
            baseVersion: Value(baseVersion),
          ),
        );
  }

  test('token yoksa runOnce hiçbir şey yapmaz', () async {
    await insertCustomer(id: 'c1');
    await enqueueCustomerOp(entityId: 'c1', operation: 'CREATE');

    await buildService(token: null).runOnce(_companyId);

    final remaining = await db.select(db.syncOperations).get();
    expect(remaining, hasLength(1));
    expect(api.createCustomerCalls, isEmpty);
  });

  test('başarılı CREATE outbox satırını siler ve entity SYNCED olur', () async {
    await insertCustomer(id: 'c1');
    await enqueueCustomerOp(entityId: 'c1', operation: 'CREATE');

    await buildService().runOnce(_companyId);

    final remaining = await db.select(db.syncOperations).get();
    expect(remaining, isEmpty);
    final customer = await (db.select(
      db.customers,
    )..where((c) => c.id.equals('c1'))).getSingle();
    expect(customer.syncStatus, 'SYNCED');
    expect(customer.version, 1);
  });

  test(
    '409 çakışması entity ve outbox satırını CONFLICT yapar, tekrar denenmez',
    () async {
      await insertCustomer(id: 'c1', version: 1);
      await enqueueCustomerOp(
        entityId: 'c1',
        operation: 'UPDATE',
        baseVersion: 1,
      );
      api.customerResponses.add(
        ApiConflictException({
          'data': {
            'base_version': 1,
            'server_version': 2,
            'server_snapshot': {'notes': 'Ofis hali'},
          },
        }),
      );

      final service = buildService();
      await service.runOnce(_companyId);

      var customer = await (db.select(
        db.customers,
      )..where((c) => c.id.equals('c1'))).getSingle();
      expect(customer.syncStatus, 'CONFLICT');
      var op = await db.select(db.syncOperations).getSingle();
      expect(op.status, 'CONFLICT');
      expect(api.updateCustomerCalls, hasLength(1));

      // İkinci çalıştırma aynı satırı tekrar denememeli (yalnızca PENDING
      // satırlar sürülür).
      await service.runOnce(_companyId);
      expect(api.updateCustomerCalls, hasLength(1));
    },
  );

  test('pull, PENDING outbox girdisi olan bir kaydın üzerine yazmaz', () async {
    await insertCustomer(id: 'c1', version: 1);
    await enqueueCustomerOp(
      entityId: 'c1',
      operation: 'UPDATE',
      baseVersion: 1,
    );
    // Drain sırasında ağ hatası — satır PENDING kalır, pull'a geçilir.
    api.customerResponses.add(ApiException(null, 'Ağ hatası'));
    api.customersToPull = [
      RemoteRecord(
        id: 'c1',
        version: 5,
        raw: {
          'code': 'CUS-1',
          'contact_name': 'Ofis Düzenlemesi',
          'company_name': null,
          'iban': null,
          'type': 'BIREYSEL',
          'phone': null,
          'email': null,
          'address': null,
          'il': null,
          'ilce': null,
          'tax_info': null,
          'notes': null,
          'tags': null,
        },
      ),
    ];

    await buildService().runOnce(_companyId);

    final customer = await (db.select(
      db.customers,
    )..where((c) => c.id.equals('c1'))).getSingle();
    // Yerel taslak (version 1, PENDING) korunmuş olmalı — sunucunun daha
    // yeni (version 5) hali sessizce üzerine yazılmamalı.
    expect(customer.version, 1);
    expect(customer.contactName, 'Test Müşteri');
  });

  test(
    'pull, PENDING outbox girdisi olmayan daha yeni bir kaydı uygular',
    () async {
      await insertCustomer(id: 'c1', version: 1, syncStatus: 'SYNCED');
      api.customersToPull = [
        RemoteRecord(
          id: 'c1',
          version: 2,
          raw: {
            'code': 'CUS-1',
            'contact_name': 'Ofis Düzenlemesi',
            'company_name': null,
            'iban': null,
            'type': 'BIREYSEL',
            'phone': null,
            'email': null,
            'address': null,
            'il': null,
            'ilce': null,
            'tax_info': null,
            'notes': null,
            'tags': null,
          },
        ),
      ];

      await buildService().runOnce(_companyId);

      final customer = await (db.select(
        db.customers,
      )..where((c) => c.id.equals('c1'))).getSingle();
      expect(customer.version, 2);
      expect(customer.contactName, 'Ofis Düzenlemesi');
    },
  );
}
