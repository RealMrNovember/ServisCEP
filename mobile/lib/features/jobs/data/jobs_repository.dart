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
    final query = _db.select(_db.jobs).join([
      innerJoin(_db.customers, _db.customers.id.equalsExp(_db.jobs.customerId)),
    ])
      ..where(_db.jobs.companyId.equals(companyId) & _db.jobs.deletedAt.isNull())
      ..orderBy([OrderingTerm.desc(_db.jobs.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map((row) => JobWithCustomer(row.readTable(_db.jobs), row.readTable(_db.customers)))
          .toList(),
    );
  }

  Stream<List<JobWithCustomer>> watchTodayForCompany(String companyId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final query = _db.select(_db.jobs).join([
      innerJoin(_db.customers, _db.customers.id.equalsExp(_db.jobs.customerId)),
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
          .map((row) => JobWithCustomer(row.readTable(_db.jobs), row.readTable(_db.customers)))
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
    return (_db.select(_db.jobs)..where((j) => j.id.equals(id))).getSingleOrNull();
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
    final countThisYear = await (_db.select(
      _db.jobs,
    )..where((j) => j.companyId.equals(companyId))).get().then((rows) => rows.length);
    final code = CodeGenerator.next('SRV', countThisYear);
    final id = _uuid.v4();

    await _db.into(_db.jobs).insert(
      JobsCompanion.insert(
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
      ),
    );
    return (await byId(id))!;
  }

  Future<void> updateStatus(String id, String status) {
    return (_db.update(_db.jobs)..where((j) => j.id.equals(id))).write(
      JobsCompanion(status: Value(status)),
    );
  }

  Future<void> update(Job job) {
    return _db.update(_db.jobs).replace(job);
  }

  /// İşi tamamlar, gerçek fiyatı kaydeder ve cari hesaba BORÇ hareketi
  /// düşer — tek bir transaction içinde (bkz. docs/07 § Transaction Kuralı,
  /// docs/15 § Otomatik Kayıt Oluşturma). Borç kaynağı tekildir: bu metod
  /// dışında hiçbir yerden job tamamlama borcu oluşturulmamalıdır.
  Future<void> completeWithPrice(Job job, int actualPriceMinor) async {
    await _db.transaction(() async {
      final updated = job.copyWith(actualPriceMinor: Value(actualPriceMinor), status: 'TAMAMLANDI');
      await _db.update(_db.jobs).replace(updated);

      await _db.into(_db.customerLedgerEntries).insert(
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
    });
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
  return ref.watch(jobsRepositoryProvider).watchTodayForCompany(session.companyId);
});

final jobsByCustomerProvider = StreamProvider.family<List<Job>, String>((ref, customerId) {
  return ref.watch(jobsRepositoryProvider).watchByCustomer(customerId);
});
