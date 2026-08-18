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
    final query = _db.select(_db.serviceRequests).join([
      innerJoin(_db.customers, _db.customers.id.equalsExp(_db.serviceRequests.customerId)),
    ])
      ..where(_db.serviceRequests.companyId.equals(companyId))
      ..orderBy([OrderingTerm.desc(_db.serviceRequests.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) =>
                RequestWithCustomer(row.readTable(_db.serviceRequests), row.readTable(_db.customers)),
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
    final countThisYear = await (_db.select(
      _db.serviceRequests,
    )..where((r) => r.companyId.equals(companyId))).get().then((rows) => rows.length);
    final code = CodeGenerator.next('REQ', countThisYear);
    final id = _uuid.v4();

    await _db.into(_db.serviceRequests).insert(
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
    return (_db.select(_db.serviceRequests)..where((r) => r.id.equals(id))).getSingle();
  }

  /// Talebi işe dönüştürür — tek transaction (bkz. docs/07 § Transaction
  /// Kuralı). Talep bağlamı (müşteri, açıklama, öncelik, adres) işe
  /// otomatik taşınır (bkz. docs/02 § Talep → İş Dönüşümü).
  Future<Job> convertToJob(ServiceRequest request) async {
    return _db.transaction(() async {
      final countThisYear = await (_db.select(
        _db.jobs,
      )..where((j) => j.companyId.equals(request.companyId))).get().then((rows) => rows.length);
      final code = CodeGenerator.next('SRV', countThisYear);
      final jobId = _uuid.v4();

      await _db.into(_db.jobs).insert(
        JobsCompanion.insert(
          id: jobId,
          companyId: request.companyId,
          code: code,
          customerId: request.customerId,
          title: request.description,
          address: Value(request.address),
          priority: Value(request.priority),
        ),
      );

      await (_db.update(_db.serviceRequests)..where((r) => r.id.equals(request.id))).write(
        ServiceRequestsCompanion(status: const Value('ISE_DONUSTU'), convertedJobId: Value(jobId)),
      );

      return (_db.select(_db.jobs)..where((j) => j.id.equals(jobId))).getSingle();
    });
  }
}

final serviceRequestsRepositoryProvider = Provider<ServiceRequestsRepository>((ref) {
  return ServiceRequestsRepository(ref.watch(databaseProvider));
});

final serviceRequestsListProvider = StreamProvider<List<RequestWithCustomer>>((ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  if (session == null) return const Stream.empty();
  return ref.watch(serviceRequestsRepositoryProvider).watchAll(session.companyId);
});
