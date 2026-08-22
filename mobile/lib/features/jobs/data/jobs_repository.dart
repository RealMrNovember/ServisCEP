import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/code_generator.dart';
import '../../auth/data/session_controller.dart';

class JobWithCustomer {
  JobWithCustomer(this.job, this.customer);
  final Job job;
  final Customer customer;
}

class JobsRepository {
  JobsRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<JobWithCustomer>> watchAll(String companyId) {
    final query =
        _db.select(_db.jobs).join([
            innerJoin(
              _db.customers,
              _db.customers.id.equalsExp(_db.jobs.customerId),
            ),
          ])
          ..where(
            _db.jobs.companyId.equals(companyId) & _db.jobs.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm.desc(_db.jobs.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => JobWithCustomer(
              row.readTable(_db.jobs),
              row.readTable(_db.customers),
            ),
          )
          .toList(),
    );
  }

  Stream<List<JobWithCustomer>> watchTodayForCompany(String companyId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final query =
        _db.select(_db.jobs).join([
            innerJoin(
              _db.customers,
              _db.customers.id.equalsExp(_db.jobs.customerId),
            ),
          ])
          ..where(
            _db.jobs.companyId.equals(companyId) &
                _db.jobs.deletedAt.isNull() &
                _db.jobs.appointmentDate.isBiggerOrEqualValue(start) &
                _db.jobs.appointmentDate.isSmallerThanValue(end),
          )
          ..orderBy([OrderingTerm.asc(_db.jobs.appointmentDate)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => JobWithCustomer(
              row.readTable(_db.jobs),
              row.readTable(_db.customers),
            ),
          )
          .toList(),
    );
  }

  Stream<List<Job>> watchByCustomer(String customerId) {
    return (_db.select(_db.jobs)
          ..where((j) => j.customerId.equals(customerId) & j.deletedAt.isNull())
          ..orderBy([(j) => OrderingTerm.desc(j.createdAt)]))
        .watch();
  }

  Future<Job?> byId(String id) {
    return (_db.select(
      _db.jobs,
    )..where((j) => j.id.equals(id))).getSingleOrNull();
  }

  Future<Job> create({
    required String companyId,
    required String customerId,
    required String title,
    String? description,
    String? address,
    DateTime? appointmentDate,
    String? startTime,
    required String priority,
  }) async {
    final countThisYear =
        await (_db.select(_db.jobs)
              ..where((j) => j.companyId.equals(companyId)))
            .get()
            .then((rows) => rows.length);
    final code = CodeGenerator.next('SRV', countThisYear);
    final id = _uuid.v4();

    final companion = JobsCompanion.insert(
      id: id,
      companyId: companyId,
      code: code,
      customerId: customerId,
      title: title,
      description: Value(description),
      address: Value(address),
      appointmentDate: Value(appointmentDate),
      startTime: Value(startTime),
      priority: Value(priority),
    );

    await _db.transaction(() async {
      await _db.into(_db.jobs).insert(companion);
      await _enqueue(
        entityId: id,
        operation: 'CREATE',
        payload: {
          'id': id,
          'code': code,
          'customer_id': customerId,
          'title': title,
          'description': description,
          'address': address,
          'appointment_date': appointmentDate?.toIso8601String(),
          'start_time': startTime,
          'priority': priority,
          // Backend'de zorunlu alan — yeni bir işin başlangıç durumu.
          'status': 'TALEP',
        },
      );
    });
    return (await byId(id))!;
  }

  Future<void> updateStatus(String id, String status) async {
    final job = await byId(id);
    if (job == null) return;
    await _db.transaction(() async {
      await (_db.update(_db.jobs)..where((j) => j.id.equals(id))).write(
        JobsCompanion(status: Value(status)),
      );
      await _enqueue(
        entityId: id,
        operation: 'UPDATE',
        baseVersion: job.version,
        payload: {'status': status},
      );
    });
  }

  /// `job.version`, çağıranın kaydı en son GÖRDÜĞÜ sürümdür — `base_version`
  /// olarak gönderilir (bkz. CustomersRepository.update ile aynı kalıp).
  Future<void> update(Job job) async {
    await _db.transaction(() async {
      await _db.update(_db.jobs).replace(job);
      await _enqueue(
        entityId: job.id,
        operation: 'UPDATE',
        baseVersion: job.version,
        payload: _jobPayload(job),
      );
    });
  }

  /// İşi tamamlar, gerçek fiyatı kaydeder ve cari hesaba BORÇ hareketi
  /// düşer — tek bir transaction içinde (bkz. docs/07 § Transaction Kuralı,
  /// docs/15 § Otomatik Kayıt Oluşturma). Borç kaynağı tekildir: bu metod
  /// dışında hiçbir yerden job tamamlama borcu oluşturulmamalıdır.
  ///
  /// Cari hesap kaydı BURADA yerel olarak oluşturulur ve senkron
  /// KUYRUĞUNA EKLENMEZ — backend, işin TAMAMLANDI güncellemesi senkron
  /// olduğunda kendi BORÇ kaydını `reference_id` bazlı idempotent olarak
  /// zaten oluşturuyor (bkz. B8/B10). İki tarafın cari hesabı bu iterasyonda
  /// ayrı ayrı hesaplanmaya devam eder — mutabakat gelecek bir iş.
  Future<void> completeWithPrice(Job job, int actualPriceMinor) async {
    await _db.transaction(() async {
      final updated = job.copyWith(
        actualPriceMinor: Value(actualPriceMinor),
        status: 'TAMAMLANDI',
      );
      await _db.update(_db.jobs).replace(updated);

      await _db
          .into(_db.customerLedgerEntries)
          .insert(
            CustomerLedgerEntriesCompanion.insert(
              id: _uuid.v4(),
              companyId: job.companyId,
              customerId: job.customerId,
              type: 'DEBIT',
              amountMinor: actualPriceMinor,
              referenceType: 'job',
              referenceId: Value(job.id),
              description: '${job.code} — ${job.title}',
            ),
          );

      await _enqueue(
        entityId: job.id,
        operation: 'UPDATE',
        baseVersion: job.version,
        payload: _jobPayload(updated),
      );
    });
  }

  Map<String, dynamic> _jobPayload(Job job) => {
    'customer_id': job.customerId,
    'job_type_id': job.jobTypeId,
    'title': job.title,
    'description': job.description,
    'address': job.address,
    'appointment_date': job.appointmentDate?.toIso8601String(),
    'start_time': job.startTime,
    'end_time': job.endTime,
    'priority': job.priority,
    'status': job.status,
    'estimated_price_minor': job.estimatedPriceMinor,
    'actual_price_minor': job.actualPriceMinor,
    'notes': job.notes,
  };

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
            entityType: 'job',
            entityId: entityId,
            operation: operation,
            payload: jsonEncode(payload),
            baseVersion: Value(baseVersion),
          ),
        );
  }
}

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return JobsRepository(ref.watch(databaseProvider));
});

final jobsListProvider = StreamProvider<List<JobWithCustomer>>((ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  if (session == null) return const Stream.empty();
  return ref.watch(jobsRepositoryProvider).watchAll(session.companyId);
});

final todaysJobsProvider = StreamProvider<List<JobWithCustomer>>((ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  if (session == null) return const Stream.empty();
  return ref
      .watch(jobsRepositoryProvider)
      .watchTodayForCompany(session.companyId);
});

final jobsByCustomerProvider = StreamProvider.family<List<Job>, String>((
  ref,
  customerId,
) {
  return ref.watch(jobsRepositoryProvider).watchByCustomer(customerId);
});
