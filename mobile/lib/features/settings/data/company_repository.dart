import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/media_storage.dart';
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

  Future<Company?> byId(String companyId) {
    return (_db.select(
      _db.companies,
    )..where((c) => c.id.equals(companyId))).getSingleOrNull();
  }

  /// Ünvan, işletme türleri ve belge antedi bilgileri.
  ///
  /// Adres/telefon/e-posta/vergi bilgisi yalnızca "ayar" değil, teklif
  /// belgesinin antedidir — bu yüzden aynı işlemde tutulur.
  Future<void> update({
    required String companyId,
    required String name,
    required List<String> businessTypes,
    String? iban,
    String? address,
    String? phone,
    String? email,
    String? taxInfo,
    String? introText,
    String? paymentTerms,
    String? deliveryTime,
    String? warrantyTerms,
  }) async {
    final joined = businessTypes.join(',');
    await _db.transaction(() async {
      await (_db.update(
        _db.companies,
      )..where((c) => c.id.equals(companyId))).write(
        CompaniesCompanion(
          name: Value(name),
          businessTypes: Value(joined),
          iban: Value(iban),
          address: Value(address),
          phone: Value(phone),
          email: Value(email),
          taxInfo: Value(taxInfo),
          introText: Value(introText),
          paymentTerms: Value(paymentTerms),
          deliveryTime: Value(deliveryTime),
          warrantyTerms: Value(warrantyTerms),
        ),
      );
      await _enqueue(companyId, 'UPDATE', {
        'name': name,
        'business_types': joined,
        'iban': iban,
        'address': address,
        'phone': phone,
        'email': email,
        'tax_info': taxInfo,
        'intro_text': introText,
        'payment_terms': paymentTerms,
        'delivery_time': deliveryTime,
        'warranty_terms': warrantyTerms,
      });
    });
  }

  /// Kırpılmış logoyu kalıcı dizine yazar, yerel kaydı günceller ve
  /// yüklemeyi outbox'a bırakır.
  Future<void> setLogo({
    required String companyId,
    required Uint8List bytes,
  }) async {
    final path = await MediaStorage.writeLogo(
      bucket: 'company_logos',
      ownerId: companyId,
      bytes: bytes,
      stamp: DateTime.now().millisecondsSinceEpoch,
    );

    await _db.transaction(() async {
      await (_db.update(
        _db.companies,
      )..where((c) => c.id.equals(companyId))).write(
        CompaniesCompanion(logoPath: Value(path), hasLogo: const Value(true)),
      );
      await _enqueue(companyId, 'LOGO', {'file_path': path});
    });
  }

  Future<void> removeLogo(String companyId) async {
    final company = await byId(companyId);

    await _db.transaction(() async {
      await (_db.update(
        _db.companies,
      )..where((c) => c.id.equals(companyId))).write(
        const CompaniesCompanion(logoPath: Value(null), hasLogo: Value(false)),
      );
      // `file_path: null` senkron motoruna "sunucudaki logoyu sil" der.
      await _enqueue(companyId, 'LOGO', const {'file_path': null});
    });

    await MediaStorage.deleteIfExists(company?.logoPath);
  }

  Future<void> _enqueue(
    String companyId,
    String operation,
    Map<String, dynamic> payload,
  ) {
    return _db
        .into(_db.syncOperations)
        .insert(
          SyncOperationsCompanion.insert(
            id: _uuid.v4(),
            entityType: 'company',
            entityId: companyId,
            operation: operation,
            payload: jsonEncode(payload),
          ),
        );
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
