import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/code_generator.dart';
import '../../auth/data/session_controller.dart';

class RequestWithCustomer {
  RequestWithCustomer(this.request, this.customer);
  final ServiceRequest request;
  final Customer customer;
}

/// Talep modülü — bkz. docs/02 § Talep Modülü.
class ServiceRequestsRepository {
  ServiceRequestsRepository(this._db);
  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<RequestWithCustomer>> watchAll(String companyId) {
    final query =
        _db.select(_db.serviceRequests).join([
            innerJoin(
              _db.customers,
              _db.customers.id.equalsExp(_db.serviceRequests.customerId),
            ),
          ])
          ..where(_db.serviceRequests.companyId.equals(companyId))
          ..orderBy([OrderingTerm.desc(_db.serviceRequests.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => RequestWithCustomer(
              row.readTable(_db.serviceRequests),
              row.readTable(_db.customers),
            ),
          )
          .toList(),
    );
  }

  Future<ServiceRequest> create({
    required String companyId,
    required String customerId,
    required String description,
    required String priority,
    String? address,
  }) async {
    final countThisYear =
        await (_db.select(_db.serviceRequests)
              ..where((r) => r.companyId.equals(companyId)))
            .get()
            .then((rows) => rows.length);
    final code = CodeGenerator.next('REQ', countThisYear);
    final id = _uuid.v4();

    await _db.transaction(() async {
      await _db
          .into(_db.serviceRequests)
          .insert(
            ServiceRequestsCompanion.insert(
              id: id,
              companyId: companyId,
              code: code,
              customerId: customerId,
              description: description,
              priority: Value(priority),
              address: Value(address),
            ),
          );
      await _enqueue(
        entityId: id,
        operation: 'CREATE',
        payload: {
          'id': id,
          'code': code,
          'customer_id': customerId,
          'description': description,
          'priority': priority,
          'address': address,
        },
      );
    });
    return (_db.select(
      _db.serviceRequests,
    )..where((r) => r.id.equals(id))).getSingle();
  }

  /// Talebi işe dönüştürür — tek transaction (bkz. docs/07 § Transaction
  /// Kuralı). Talep bağlamı (müşteri, açıklama, öncelik, adres) işe
  /// otomatik taşınır (bkz. docs/02 § Talep → İş Dönüşümü).
  ///
  /// Senkron: iş için ayrıca bir job CREATE kuyruklanmaz — backend'in
  /// `/convert` endpoint'i işi bizim verdiğimiz UUID ile kendisi oluşturur
  /// (tek CONVERT operasyonu, iki ayrı isteğin yarıda kesilme riski yok).
  /// Yerel üretilen kod/başlık, senkron yanıtındaki sunucu değerleriyle
  /// güncellenir (bkz. sync_service.dart).
  Future<Job> convertToJob(ServiceRequest request) async {
    return _db.transaction(() async {
      final countThisYear =
          await (_db.select(_db.jobs)
                ..where((j) => j.companyId.equals(request.companyId)))
              .get()
              .then((rows) => rows.length);
      final code = CodeGenerator.next('SRV', countThisYear);
      final jobId = _uuid.v4();

      // Başlık/açıklama ayrımı backend'in türetmesiyle aynı tutulur
      // (ServiceRequestService::convertToJob: title = ilk 80 karakter,
      // description = tam metin) — senkron sonrası alan sapması olmasın.
      final title = request.description.length > 80
          ? request.description.substring(0, 80)
          : request.description;

      await _db
          .into(_db.jobs)
          .insert(
            JobsCompanion.insert(
              id: jobId,
              companyId: request.companyId,
              code: code,
              customerId: request.customerId,
              title: title,
              description: Value(request.description),
              address: Value(request.address),
              priority: Value(request.priority),
            ),
          );

      await (_db.update(
        _db.serviceRequests,
      )..where((r) => r.id.equals(request.id))).write(
        ServiceRequestsCompanion(
          status: const Value('ISE_DONUSTU'),
          convertedJobId: Value(jobId),
        ),
      );

      await _enqueue(
        entityId: request.id,
        operation: 'CONVERT',
        payload: {'job_id': jobId},
      );

      return (_db.select(
        _db.jobs,
      )..where((j) => j.id.equals(jobId))).getSingle();
    });
  }

  /// Talebi reddeder.
  ///
  /// Silinmiyor, durumu değişiyor: müşteriden gelen bir talebin izi
  /// kalmalı — "biz böyle bir talep almadık" tartışmasına düşülmesin.
  Future<void> reject(ServiceRequest request) async {
    await _db.transaction(() async {
      await (_db.update(
        _db.serviceRequests,
      )..where((r) => r.id.equals(request.id))).write(
        const ServiceRequestsCompanion(
          status: Value('REDDEDILDI'),
          syncStatus: Value('PENDING'),
        ),
      );

      await _enqueue(
        entityId: request.id,
        operation: 'UPDATE',
        baseVersion: request.version,
        payload: const {
          'status': 'REDDEDILDI',
          'changed_fields': ['status'],
        },
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
            entityType: 'service_request',
            entityId: entityId,
            operation: operation,
            payload: jsonEncode(payload),
            baseVersion: Value(baseVersion),
          ),
        );
  }
}

final serviceRequestsRepositoryProvider = Provider<ServiceRequestsRepository>((
  ref,
) {
  return ServiceRequestsRepository(ref.watch(databaseProvider));
});

final serviceRequestsListProvider = StreamProvider<List<RequestWithCustomer>>((
  ref,
) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  if (session == null) return const Stream.empty();
  return ref
      .watch(serviceRequestsRepositoryProvider)
      .watchAll(session.companyId);
});
