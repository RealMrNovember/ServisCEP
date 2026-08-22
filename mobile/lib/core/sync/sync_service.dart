import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../network/api_client.dart';
import '../network/sync_api_client.dart';
import '../network/token_store.dart';
import '../providers/core_providers.dart';

/// Mobil senkron motoru — bkz. ROADMAP.md § B10 mobil yarısı.
///
/// Akış: önce outbox'taki bekleyen yazmalar sunucuya gönderilir (push),
/// sonra Customer/Job listeleri sunucudan çekilip yerel taze olmayan
/// kayıtlar güncellenir (pull). Bir kaydın PENDING bir outbox girdisi
/// varsa pull o kaydı EZMEZ — "telefon offline yazdı, ofis de yazdı"
/// senaryosunda yerel taslağın üzerine sessizce yazılmaması bu motorun
/// asıl amacı.
///
/// Kapsam sınırı: yalnızca Customer + Job senkronlanıyor (dikey dilim).
/// Silinen kayıtlar (backend'in geri dönüşüm kutusu) pull listesine
/// girmez — bu yüzden ofis tarafında silinen bir müşteri, telefonda
/// kendisine dokunulmadığı sürece görünmeye devam eder. Tam simetrik
/// tombstone senkronu bu iterasyonun kapsamı dışında.
class SyncService {
  SyncService(this._db, this._api, this._tokenStore);

  final AppDatabase _db;
  final SyncApiClient _api;
  final TokenStore _tokenStore;

  Future<void> runOnce(String companyId) async {
    if (await _tokenStore.read() == null) return;

    await _drainOutbox();
    await _pullCustomers(companyId);
    await _pullJobs(companyId);
  }

  Future<void> _drainOutbox() async {
    final pending =
        await (_db.select(_db.syncOperations)
              ..where((o) => o.status.equals('PENDING'))
              ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
            .get();

    for (final op in pending) {
      final payload = jsonDecode(op.payload) as Map<String, dynamic>;
      try {
        switch ((op.entityType, op.operation)) {
          case ('customer', 'CREATE'):
            final result = await _api.createCustomer(payload);
            await _markSynced('customer', result);
          case ('customer', 'UPDATE'):
            final result = await _api.updateCustomer(op.entityId, {
              ...payload,
              'base_version': op.baseVersion,
            });
            await _markSynced('customer', result);
          case ('customer', 'DELETE'):
            await _api.deleteCustomer(op.entityId);
          case ('job', 'CREATE'):
            final result = await _api.createJob(payload);
            await _markSynced('job', result);
          case ('job', 'UPDATE'):
            final result = await _api.updateJob(op.entityId, {
              ...payload,
              'base_version': op.baseVersion,
            });
            await _markSynced('job', result);
          default:
            throw StateError(
              'Bilinmeyen sync operasyonu: ${op.entityType}/${op.operation}',
            );
        }
        await _db.delete(_db.syncOperations).delete(op);
      } on ApiConflictException catch (e) {
        await _markConflicted(op, e);
      } on ApiException catch (e) {
        if (e.statusCode == null) {
          // Ağ hatası — bu ve kalan kuyruk bir sonraki tetiklemede tekrar
          // denenecek, şimdi hammer etmeden çık.
          return;
        }
        await _markFailed(op, e);
      }
    }
  }

  Future<void> _markSynced(String entityType, SyncEntityResult result) {
    if (entityType == 'customer') {
      return (_db.update(
        _db.customers,
      )..where((c) => c.id.equals(result.id))).write(
        CustomersCompanion(
          version: Value(result.version),
          syncStatus: const Value('SYNCED'),
        ),
      );
    }
    return (_db.update(_db.jobs)..where((j) => j.id.equals(result.id))).write(
      JobsCompanion(
        version: Value(result.version),
        syncStatus: const Value('SYNCED'),
      ),
    );
  }

  Future<void> _markConflicted(SyncOperation op, ApiConflictException e) async {
    await (_db.update(
      _db.syncOperations,
    )..where((o) => o.id.equals(op.id))).write(
      SyncOperationsCompanion(
        status: const Value('CONFLICT'),
        lastError: Value(jsonEncode(e.serverSnapshot)),
      ),
    );
    final syncStatus = const Value('CONFLICT');
    if (op.entityType == 'customer') {
      await (_db.update(_db.customers)..where((c) => c.id.equals(op.entityId)))
          .write(CustomersCompanion(syncStatus: syncStatus));
    } else {
      await (_db.update(_db.jobs)..where((j) => j.id.equals(op.entityId)))
          .write(JobsCompanion(syncStatus: syncStatus));
    }
  }

  Future<void> _markFailed(SyncOperation op, ApiException e) async {
    await (_db.update(
      _db.syncOperations,
    )..where((o) => o.id.equals(op.id))).write(
      SyncOperationsCompanion(
        status: const Value('FAILED'),
        lastError: Value(e.message),
        attemptCount: Value(op.attemptCount + 1),
      ),
    );
    final syncStatus = const Value('FAILED');
    if (op.entityType == 'customer') {
      await (_db.update(_db.customers)..where((c) => c.id.equals(op.entityId)))
          .write(CustomersCompanion(syncStatus: syncStatus));
    } else {
      await (_db.update(_db.jobs)..where((j) => j.id.equals(op.entityId)))
          .write(JobsCompanion(syncStatus: syncStatus));
    }
  }

  Future<bool> _hasPendingOutboxFor(String entityId) async {
    final row =
        await (_db.select(_db.syncOperations)..where(
              (o) => o.entityId.equals(entityId) & o.status.equals('PENDING'),
            ))
            .getSingleOrNull();
    return row != null;
  }

  Future<void> _pullCustomers(String companyId) async {
    final remoteRecords = await _api.listCustomers();
    for (final remote in remoteRecords) {
      if (await _hasPendingOutboxFor(remote.id)) continue;

      final local = await (_db.select(
        _db.customers,
      )..where((c) => c.id.equals(remote.id))).getSingleOrNull();
      if (local != null && local.version >= remote.version) continue;

      final r = remote.raw;
      final companion = CustomersCompanion(
        id: Value(remote.id),
        companyId: Value(companyId),
        code: Value(r['code'] as String),
        contactName: Value(r['contact_name'] as String?),
        companyName: Value(r['company_name'] as String?),
        iban: Value(r['iban'] as String?),
        type: Value(r['type'] as String),
        phone: Value(r['phone'] as String?),
        email: Value(r['email'] as String?),
        address: Value(r['address'] as String?),
        il: Value(r['il'] as String?),
        ilce: Value(r['ilce'] as String?),
        taxInfo: Value(r['tax_info'] as String?),
        notes: Value(r['notes'] as String?),
        tags: Value(r['tags'] as String?),
        version: Value(remote.version),
        syncStatus: const Value('SYNCED'),
      );
      await _db.into(_db.customers).insertOnConflictUpdate(companion);
    }
  }

  Future<void> _pullJobs(String companyId) async {
    final remoteRecords = await _api.listJobs();
    for (final remote in remoteRecords) {
      if (await _hasPendingOutboxFor(remote.id)) continue;

      final local = await (_db.select(
        _db.jobs,
      )..where((j) => j.id.equals(remote.id))).getSingleOrNull();
      if (local != null && local.version >= remote.version) continue;

      final r = remote.raw;
      final companion = JobsCompanion(
        id: Value(remote.id),
        companyId: Value(companyId),
        code: Value(r['code'] as String),
        customerId: Value(r['customer_id'] as String),
        jobTypeId: Value(r['job_type_id'] as String?),
        title: Value(r['title'] as String),
        description: Value(r['description'] as String?),
        address: Value(r['address'] as String?),
        appointmentDate: Value(
          r['appointment_date'] == null
              ? null
              : DateTime.parse(r['appointment_date'] as String),
        ),
        startTime: Value(r['start_time'] as String?),
        endTime: Value(r['end_time'] as String?),
        priority: Value(r['priority'] as String),
        status: Value(r['status'] as String),
        technicianUserId: Value(r['technician_user_id'] as String?),
        estimatedPriceMinor: Value(
          (r['estimated_price_minor'] as num?)?.toInt(),
        ),
        actualPriceMinor: Value((r['actual_price_minor'] as num?)?.toInt()),
        notes: Value(r['notes'] as String?),
        version: Value(remote.version),
        syncStatus: const Value('SYNCED'),
      );
      await _db.into(_db.jobs).insertOnConflictUpdate(companion);
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ref.watch(databaseProvider),
    ref.watch(syncApiClientProvider),
    ref.watch(tokenStoreProvider),
  );
});
