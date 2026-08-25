import 'dart:convert';
import 'dart:io';

// drift ve matcher aynı isimleri (isNull/isNotNull) tanımlıyor — testte
// beklenen anlam matcher'ınki, bu yüzden drift tarafı gizleniyor.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/core/database/app_database.dart';
import 'package:serviscep/core/network/api_client.dart';
import 'package:serviscep/core/network/sync_api_client.dart';
import 'package:serviscep/core/sync/sync_service.dart';
import 'package:serviscep/features/sync/data/sync_conflict_repository.dart';

import '../../support/fake_sync_api_client.dart';
import '../../support/fake_token_store.dart';
import '../../support/in_memory_database.dart';

const _companyId = 'company-1';

File createTempFile(String name) =>
    File('${Directory.systemTemp.path}/$name')..writeAsBytesSync([1, 2, 3]);

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

  SyncService buildService() =>
      SyncService(db, api, FakeTokenStore(initialToken: 'test-token'));

  Future<void> insertCustomer(String id, {DateTime? deletedAt}) {
    return db
        .into(db.customers)
        .insert(
          CustomersCompanion.insert(
            id: id,
            companyId: _companyId,
            code: 'CUS-1',
            contactName: const Value('Test Müşteri'),
            syncStatus: const Value('SYNCED'),
            deletedAt: Value(deletedAt),
          ),
        );
  }

  RemoteRecord trashedRecord(String id) => RemoteRecord(
    id: id,
    version: 1,
    raw: {'id': id, 'code': 'CUS-1', 'type': 'BIREYSEL'},
  );

  group('tombstone senkronu', () {
    test('ofiste silinen müşteri yerelde de silinir', () async {
      await insertCustomer('c1');
      api.trashedCustomersToPull = [trashedRecord('c1')];

      await buildService().runOnce(_companyId);

      final customer = await (db.select(
        db.customers,
      )..where((c) => c.id.equals('c1'))).getSingle();
      expect(customer.deletedAt, isNotNull);
      expect(customer.syncStatus, 'SYNCED');
    });

    test(
      'bekleyen yerel yazması olan müşteri tombstone ile SİLİNMEZ',
      () async {
        await insertCustomer('c2');
        await db
            .into(db.syncOperations)
            .insert(
              SyncOperationsCompanion.insert(
                id: 'op-1',
                entityType: 'customer',
                entityId: 'c2',
                operation: 'UPDATE',
                payload: jsonEncode({'contact_name': 'Telefondaki hali'}),
                baseVersion: const Value(1),
              ),
            );
        api.trashedCustomersToPull = [trashedRecord('c2')];
        // Push başarısız olsun ki outbox satırı PENDING kalsın (ağ hatası).
        api.customerResponses.add(ApiException(null, 'Ağ hatası'));

        await buildService().runOnce(_companyId);

        final customer = await (db.select(
          db.customers,
        )..where((c) => c.id.equals('c2'))).getSingle();
        expect(
          customer.deletedAt,
          isNull,
          reason: 'kullanıcının bekleyen yazması sessizce silinmemeli',
        );
      },
    );

    test('zaten silinmiş kayıt tekrar işlenmez', () async {
      final deletedAt = DateTime(2026, 8, 1);
      await insertCustomer('c3', deletedAt: deletedAt);
      api.trashedCustomersToPull = [trashedRecord('c3')];

      await buildService().runOnce(_companyId);

      final customer = await (db.select(
        db.customers,
      )..where((c) => c.id.equals('c3'))).getSingle();
      expect(customer.deletedAt, deletedAt);
    });
  });

  group('çakışma çözümü', () {
    test('çözüm sunucuya gider, yerel CONFLICT izleri temizlenir', () async {
      await db
          .into(db.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'c9',
              companyId: _companyId,
              code: 'CUS-9',
              contactName: const Value('Çakışan'),
              syncStatus: const Value('CONFLICT'),
            ),
          );
      await db
          .into(db.syncOperations)
          .insert(
            SyncOperationsCompanion.insert(
              id: 'op-conflict',
              entityType: 'customer',
              entityId: 'c9',
              operation: 'UPDATE',
              payload: jsonEncode({'contact_name': 'Telefon hali'}),
              status: const Value('CONFLICT'),
            ),
          );

      final conflict = PendingConflict.fromJson({
        'id': 'conflict-1',
        'subject_type': 'customer',
        'subject_id': 'c9',
        'base_version': 1,
        'server_version': 2,
        'incoming_payload': {'contact_name': 'Telefon hali', 'phone': '555'},
        'server_snapshot': {'contact_name': 'Ofis hali', 'phone': '555'},
        'created_at': '2026-08-24T10:00:00Z',
      });

      await SyncConflictRepository(api, db).resolve(conflict, 'MOBIL_TUTULDU');

      expect(api.resolveConflictCalls, [('conflict-1', 'MOBIL_TUTULDU')]);
      expect(await db.select(db.syncOperations).get(), isEmpty);
      final customer = await (db.select(
        db.customers,
      )..where((c) => c.id.equals('c9'))).getSingle();
      expect(customer.syncStatus, 'SYNCED');
    });

    test('fark listesi yalnızca gerçekten değişen alanları gösterir', () {
      final conflict = PendingConflict.fromJson({
        'id': 'conflict-2',
        'subject_type': 'customer',
        'subject_id': 'c9',
        'base_version': 1,
        'server_version': 2,
        'incoming_payload': {
          'id': 'c9',
          'contact_name': 'Telefon hali',
          'phone': '555',
          'notes': null,
        },
        'server_snapshot': {
          'id': 'c9',
          'contact_name': 'Ofis hali',
          'phone': '555',
          'notes': '',
        },
        'created_at': '2026-08-24T10:00:00Z',
      });

      final diffs = conflict.differences;

      expect(diffs, hasLength(1));
      expect(diffs.single.field, 'contact_name');
      expect(diffs.single.label, 'Yetkili adı');
      expect(diffs.single.mine, 'Telefon hali');
      expect(diffs.single.server, 'Ofis hali');
    });
  });

  group('vergi levhası', () {
    test('outbox TAX_CERTIFICATE satırı yüklemeyi tetikler', () async {
      await insertCustomer('c5');
      final tempFile = createTempFile('levha.jpg');
      addTearDown(tempFile.deleteSync);

      await db
          .into(db.syncOperations)
          .insert(
            SyncOperationsCompanion.insert(
              id: 'op-tax',
              entityType: 'customer',
              entityId: 'c5',
              operation: 'TAX_CERTIFICATE',
              payload: jsonEncode({'file_path': tempFile.path}),
            ),
          );

      await buildService().runOnce(_companyId);

      expect(api.uploadTaxCertificateCalls, [('c5', tempFile.path)]);
      final customer = await (db.select(
        db.customers,
      )..where((c) => c.id.equals('c5'))).getSingle();
      expect(customer.hasTaxCertificate, isTrue);
      expect(await db.select(db.syncOperations).get(), isEmpty);
    });
  });
}
