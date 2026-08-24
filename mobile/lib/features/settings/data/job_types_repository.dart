import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/job_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/data/session_controller.dart';

/// Kullanıcının kendi iş türleri — hazır katalog (jobTypeCatalog,
/// docs/02 § İş Türleri) yetmediğinde eklenen özel türler.
///
/// Yalnızca YEREL tutulur: iş türü bir katalog/otomatik tamamlama
/// yardımcısıdır, işin kendisi zaten `title` alanında serbest metin olarak
/// senkronlanır. Bu yüzden senkron kuyruğuna girmez — sunucuda karşılığı
/// olmayan bir kaydı senkronlamak gereksiz karmaşıklık olurdu.
class JobTypesRepository {
  JobTypesRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<JobType>> watchCustom(String companyId) {
    return (_db.select(_db.jobTypes)
          ..where((t) => t.companyId.equals(companyId) & t.isCustom.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<void> add({
    required String companyId,
    required String category,
    required String name,
  }) {
    return _db
        .into(_db.jobTypes)
        .insert(
          JobTypesCompanion.insert(
            id: _uuid.v4(),
            companyId: companyId,
            category: category,
            name: name,
            isCustom: const Value(true),
          ),
        );
  }

  Future<void> remove(String id) {
    return (_db.delete(_db.jobTypes)..where((t) => t.id.equals(id))).go();
  }
}

final jobTypesRepositoryProvider = Provider<JobTypesRepository>((ref) {
  return JobTypesRepository(ref.watch(databaseProvider));
});

final customJobTypesProvider = StreamProvider<List<JobType>>((ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  if (session == null) return const Stream.empty();
  return ref.watch(jobTypesRepositoryProvider).watchCustom(session.companyId);
});

/// İş formundaki otomatik tamamlama için: hazır katalog + kullanıcının
/// kendi türleri, tek bir liste hâlinde.
final allJobTypeNamesProvider = Provider<List<String>>((ref) {
  final custom = ref.watch(customJobTypesProvider).valueOrNull ?? const [];
  return [
    ...custom.map((t) => t.name),
    ...jobTypeCatalog.values.expand((v) => v),
  ];
});
