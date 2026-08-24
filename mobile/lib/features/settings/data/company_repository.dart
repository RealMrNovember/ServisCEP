import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/core_providers.dart';
import '../../auth/data/session_controller.dart';

/// Şirket ayarları — bkz. backend CompanyController.
///
/// Yazma önce YERELE yapılır, sunucuya outbox üzerinden gider: ayarlar
/// çevrimdışıyken de değiştirilebilir.
///
/// Bilinçli tasarım notu: şirket kaydında sürüm (version) tabanlı çakışma
/// kontrolü YOKTUR — Customer/Job'dan farklı olarak bu kaydı yalnızca
/// işletme sahibi, çok seyrek düzenler. "Son yazan kazanır" burada kabul
/// edilebilir; iki cihazın aynı anda şirket ünvanını değiştirmesi gerçekçi
/// bir senaryo değil.
class CompanyRepository {
  CompanyRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<Company?> watch(String companyId) {
    return (_db.select(
      _db.companies,
    )..where((c) => c.id.equals(companyId))).watchSingleOrNull();
  }

  Future<void> update({
    required String companyId,
    required String name,
    required List<String> businessTypes,
    String? iban,
  }) async {
    final joined = businessTypes.join(',');
    await _db.transaction(() async {
      await (_db.update(_db.companies)..where((c) => c.id.equals(companyId)))
          .write(
            CompaniesCompanion(
              name: Value(name),
              businessTypes: Value(joined),
              iban: Value(iban),
            ),
          );
      await _db
          .into(_db.syncOperations)
          .insert(
            SyncOperationsCompanion.insert(
              id: _uuid.v4(),
              entityType: 'company',
              entityId: companyId,
              operation: 'UPDATE',
              payload: jsonEncode({
                'name': name,
                'business_types': joined,
                'iban': iban,
              }),
            ),
          );
    });
  }
}

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepository(ref.watch(databaseProvider));
});

final currentCompanyProvider = StreamProvider<Company?>((ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  if (session == null) return const Stream.empty();
  return ref.watch(companyRepositoryProvider).watch(session.companyId);
});
