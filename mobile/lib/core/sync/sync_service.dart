import 'dart:convert';
import 'dart:io';

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
/// sonra sunucu listeleri çekilip yerel taze olmayan kayıtlar güncellenir
/// (pull). Bir kaydın PENDING bir outbox girdisi varsa pull o kaydı EZMEZ —
/// "telefon offline yazdı, ofis de yazdı" senaryosunda yerel taslağın
/// üzerine sessizce yazılmaması bu motorun asıl amacı.
///
/// Kapsam (dikey dilim 2 + medya, 2026-08-24):
/// - Push + pull: Customer, Job, ServiceRequest, Quote, Proforma
/// - Push-only: Payment, IncomeEntry, ExpenseEntry (create-only kayıtlar —
///   sunucuda düzenlenmezler, çakışma riski yok; pull edilmemeleri bilinçli,
///   web panelde girilen finans kayıtları mobilde görünmez)
/// - Push-only (medya): JobNote, JobPhoto, JobSignature — dosyalar payload'da
///   değil, gönderim anında diskten multipart okunur; dosya silinmişse satır
///   FAILED olur (sessizce atlanmaz). Panelde eklenen medya mobile İNMEZ
///   (medya telefonda üretilir, panel görüntüleme yeridir).
/// - Kapsam dışı (değişmedi): CustomerLedgerEntries (iki taraf bağımsız
///   hesaplar), silinen kayıtların tombstone senkronu.
class SyncService {
  SyncService(this._db, this._api, this._tokenStore);

  final AppDatabase _db;
  final SyncApiClient _api;
  final TokenStore _tokenStore;

  Future<void> runOnce(String companyId) async {
    if (await _tokenStore.read() == null) return;

    await _drainOutbox();
    try {
      await _pullCustomers(companyId);
      await _pullJobs(companyId);
      await _pullServiceRequests(companyId);
      await _pullQuotes(companyId);
      await _pullProformas(companyId);
    } on ApiException {
      // Ağ hatası, süresi dolmuş abonelik (402) veya geçici sunucu hatası —
      // pull bir sonraki tetiklemede yeniden dener; `runOnce` unawaited
      // çağrıldığı için buradan exception SIZMAMALI (bkz. SyncTrigger).
      return;
    }
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
          case ('service_request', 'CREATE'):
            final result = await _api.createServiceRequest(payload);
            await _markSynced('service_request', result);
          case ('service_request', 'CONVERT'):
            // Backend işi bizim job_id'mizle kendisi oluşturur ve işin son
            // hâlini döndürür — yerel iş (kod/başlık sunucu türetmesiyle)
            // hizalanır. Talebin yeni version'ı yanıtında yok; bir sonraki
            // pull düzeltir, şimdilik SYNCED işaretlemek yeterli.
            final job = await _api.convertServiceRequest(
              op.entityId,
              payload['job_id'] as String,
            );
            await _applyConvertedJob(job);
            await (_db.update(_db.serviceRequests)
                  ..where((r) => r.id.equals(op.entityId)))
                .write(
                  const ServiceRequestsCompanion(
                    syncStatus: Value('SYNCED'),
                  ),
                );
          case ('quote', 'CREATE'):
            final result = await _api.createQuote(payload);
            await _markSynced('quote', result);
          case ('quote', 'UPDATE'):
            final result = await _api.updateQuote(op.entityId, {
              ...payload,
              'base_version': op.baseVersion,
            });
            await _markSynced('quote', result);
          case ('proforma', 'CREATE'):
            final result = await _api.createProforma(payload);
            await _markSynced('proforma', result);
          case ('payment', 'CREATE'):
            // customer_id URL yolu içindir, istek gövdesine girmez.
            final body = Map<String, dynamic>.from(payload)
              ..remove('customer_id');
            await _api.createPayment(payload['customer_id'] as String, body);
          case ('income_entry', 'CREATE'):
            await _api.createIncomeEntry(payload);
          case ('expense_entry', 'CREATE'):
            await _api.createExpenseEntry(payload);
          case ('customer', 'TAX_CERTIFICATE'):
            if (!File(payload['file_path'] as String).existsSync()) {
              await _markFailed(
                op,
                ApiException(422, 'Vergi levhası dosyası artık cihazda yok.'),
              );
              continue;
            }
            await _api.uploadTaxCertificate(
              op.entityId,
              payload['file_path'] as String,
            );
            await (_db.update(_db.customers)
                  ..where((c) => c.id.equals(op.entityId)))
                .write(
                  const CustomersCompanion(hasTaxCertificate: Value(true)),
                );
          case ('company', 'UPDATE'):
            await _api.updateCompany(payload);
          case ('job_note', 'CREATE'):
            await _api.createJobNote(payload['job_id'] as String, {
              'id': payload['id'],
              'note': payload['note'],
            });
          case ('job_photo', 'CREATE'):
            if (!File(payload['file_path'] as String).existsSync()) {
              await _markFailed(
                op,
                ApiException(422, 'Fotoğraf dosyası artık cihazda yok.'),
              );
              continue;
            }
            await _api.createJobPhoto(
              payload['job_id'] as String,
              id: payload['id'] as String,
              category: payload['category'] as String,
              filePath: payload['file_path'] as String,
            );
          case ('job_signature', 'CREATE'):
            if (!File(payload['file_path'] as String).existsSync()) {
              await _markFailed(
                op,
                ApiException(422, 'İmza dosyası artık cihazda yok.'),
              );
              continue;
            }
            await _api.createJobSignature(
              payload['job_id'] as String,
              id: payload['id'] as String,
              signerName: payload['signer_name'] as String,
              filePath: payload['file_path'] as String,
            );
          default:
            throw StateError(
              'Bilinmeyen sync operasyonu: ${op.entityType}/${op.operation}',
            );
        }
        await _db.delete(_db.syncOperations).delete(op);
      } on ApiConflictException catch (e) {
        await _markConflicted(op, e);
      } on ApiException catch (e) {
        if (e.statusCode == null || e.statusCode == 402) {
          // Ağ hatası veya abonelik süresi dolmuş (402) — kuyruk PENDING
          // kalır: veri kaybolmaz, bağlantı/yenileme sonrası akar. 402'de
          // satırları FAILED işaretlemek yanlış olurdu; sorun veride değil,
          // abonelikte (bkz. backend EnsureSubscriptionIsActive).
          return;
        }
        await _markFailed(op, e);
      }
    }
  }

  /// Convert yanıtındaki işin sunucu hâlini yerel kayda uygular — kod
  /// (sunucu 'J-...' üretir, yerel 'SRV-...' idi) ve başlık/açıklama
  /// türetmesi sunucuyla hizalanır.
  Future<void> _applyConvertedJob(Map<String, dynamic> job) {
    return (_db.update(
      _db.jobs,
    )..where((j) => j.id.equals(job['id'] as String))).write(
      JobsCompanion(
        code: Value(job['code'] as String),
        title: Value(job['title'] as String),
        description: Value(job['description'] as String?),
        version: Value((job['version'] as num?)?.toInt() ?? 1),
        syncStatus: const Value('SYNCED'),
      ),
    );
  }

  Future<void> _markSynced(String entityType, SyncEntityResult result) async {
    final version = Value(result.version);
    const synced = Value('SYNCED');
    switch (entityType) {
      case 'customer':
        await (_db.update(_db.customers)..where((c) => c.id.equals(result.id)))
            .write(CustomersCompanion(version: version, syncStatus: synced));
      case 'job':
        await (_db.update(_db.jobs)..where((j) => j.id.equals(result.id)))
            .write(JobsCompanion(version: version, syncStatus: synced));
      case 'service_request':
        await (_db.update(_db.serviceRequests)
              ..where((r) => r.id.equals(result.id)))
            .write(
              ServiceRequestsCompanion(version: version, syncStatus: synced),
            );
      case 'quote':
        await (_db.update(_db.quotes)..where((q) => q.id.equals(result.id)))
            .write(QuotesCompanion(version: version, syncStatus: synced));
      case 'proforma':
        await (_db.update(_db.proformas)..where((p) => p.id.equals(result.id)))
            .write(ProformasCompanion(version: version, syncStatus: synced));
      // payment / income_entry / expense_entry: yerel tabloda syncStatus
      // kolonu yok (create-only) — outbox satırının silinmesi yeterli.
    }
  }

  Future<void> _setEntitySyncStatus(SyncOperation op, String status) async {
    final value = Value(status);
    switch (op.entityType) {
      case 'customer':
        await (_db.update(_db.customers)..where((c) => c.id.equals(op.entityId)))
            .write(CustomersCompanion(syncStatus: value));
      case 'job':
        await (_db.update(_db.jobs)..where((j) => j.id.equals(op.entityId)))
            .write(JobsCompanion(syncStatus: value));
      case 'service_request':
        await (_db.update(_db.serviceRequests)
              ..where((r) => r.id.equals(op.entityId)))
            .write(ServiceRequestsCompanion(syncStatus: value));
      case 'quote':
        await (_db.update(_db.quotes)..where((q) => q.id.equals(op.entityId)))
            .write(QuotesCompanion(syncStatus: value));
      case 'proforma':
        await (_db.update(_db.proformas)
              ..where((p) => p.id.equals(op.entityId)))
            .write(ProformasCompanion(syncStatus: value));
    }
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
    await _setEntitySyncStatus(op, 'CONFLICT');
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
    await _setEntitySyncStatus(op, 'FAILED');
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
        hasTaxCertificate: Value(r['has_tax_certificate'] as bool? ?? false),
        version: Value(remote.version),
        syncStatus: const Value('SYNCED'),
      );
      await _db.into(_db.customers).insertOnConflictUpdate(companion);
    }

    await _pullTrashedCustomers();
  }

  /// Tombstone senkronu — ofiste (web panelde) silinen müşteri telefonda
  /// da silinmiş görünmeli. Backend silinen müşteriyi 3 gün çöp kutusunda
  /// tutar; bu pencerede burada yakalanır ve yerelde soft-delete edilir.
  ///
  /// PENDING outbox girdisi olan kayıt ATLANIR: telefon aynı müşteriyi
  /// offline düzenlediyse, kullanıcının bekleyen yazması sessizce
  /// silinmez — önce push edilir, sonuç (409/başarı) ona göre işlenir.
  Future<void> _pullTrashedCustomers() async {
    final trashed = await _api.listTrashedCustomers();
    for (final remote in trashed) {
      if (await _hasPendingOutboxFor(remote.id)) continue;

      final local = await (_db.select(
        _db.customers,
      )..where((c) => c.id.equals(remote.id))).getSingleOrNull();
      if (local == null || local.deletedAt != null) continue;

      await (_db.update(_db.customers)..where((c) => c.id.equals(remote.id)))
          .write(
            CustomersCompanion(
              deletedAt: Value(DateTime.now()),
              syncStatus: const Value('SYNCED'),
            ),
          );
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

  Future<void> _pullServiceRequests(String companyId) async {
    final remoteRecords = await _api.listServiceRequests();
    for (final remote in remoteRecords) {
      if (await _hasPendingOutboxFor(remote.id)) continue;

      final local = await (_db.select(
        _db.serviceRequests,
      )..where((r) => r.id.equals(remote.id))).getSingleOrNull();
      if (local != null && local.version >= remote.version) continue;

      final r = remote.raw;
      final companion = ServiceRequestsCompanion(
        id: Value(remote.id),
        companyId: Value(companyId),
        code: Value(r['code'] as String),
        customerId: Value(r['customer_id'] as String),
        description: Value(r['description'] as String),
        priority: Value(r['priority'] as String),
        address: Value(r['address'] as String?),
        status: Value(r['status'] as String),
        convertedJobId: Value(r['converted_job_id'] as String?),
        version: Value(remote.version),
        syncStatus: const Value('SYNCED'),
      );
      await _db.into(_db.serviceRequests).insertOnConflictUpdate(companion);
    }
  }

  Future<void> _pullQuotes(String companyId) async {
    final remoteRecords = await _api.listQuotes();
    for (final remote in remoteRecords) {
      if (await _hasPendingOutboxFor(remote.id)) continue;

      final local = await (_db.select(
        _db.quotes,
      )..where((q) => q.id.equals(remote.id))).getSingleOrNull();
      if (local != null && local.version >= remote.version) continue;

      final r = remote.raw;
      await _db.transaction(() async {
        await _db.into(_db.quotes).insertOnConflictUpdate(
          QuotesCompanion(
            id: Value(remote.id),
            companyId: Value(companyId),
            code: Value(r['code'] as String),
            customerId: Value(r['customer_id'] as String),
            status: Value(r['status'] as String),
            notes: Value(r['notes'] as String?),
            totalMinor: Value((r['total_minor'] as num?)?.toInt() ?? 0),
            version: Value(remote.version),
            syncStatus: const Value('SYNCED'),
          ),
        );
        await _replaceDocItems(
          quoteId: remote.id,
          items: (r['items'] as List<dynamic>?) ?? const [],
        );
      });
    }
  }

  Future<void> _pullProformas(String companyId) async {
    final remoteRecords = await _api.listProformas();
    for (final remote in remoteRecords) {
      if (await _hasPendingOutboxFor(remote.id)) continue;

      final local = await (_db.select(
        _db.proformas,
      )..where((p) => p.id.equals(remote.id))).getSingleOrNull();
      if (local != null && local.version >= remote.version) continue;

      final r = remote.raw;
      await _db.transaction(() async {
        await _db.into(_db.proformas).insertOnConflictUpdate(
          ProformasCompanion(
            id: Value(remote.id),
            companyId: Value(companyId),
            code: Value(r['code'] as String),
            customerId: Value(r['customer_id'] as String),
            validUntil: Value(
              r['valid_until'] == null
                  ? null
                  : DateTime.parse(r['valid_until'] as String),
            ),
            notes: Value(r['notes'] as String?),
            totalMinor: Value((r['total_minor'] as num?)?.toInt() ?? 0),
            version: Value(remote.version),
            syncStatus: const Value('SYNCED'),
          ),
        );
        await _replaceDocItems(
          proformaId: remote.id,
          items: (r['items'] as List<dynamic>?) ?? const [],
        );
      });
    }
  }

  /// Belge kalemlerini sunucudakiyle bire bir değiştirir — kalemler belge
  /// oluşturulduktan sonra düzenlenemez (immutable), bu yüzden satır bazlı
  /// merge yerine toptan değişim yeterli ve güvenli.
  Future<void> _replaceDocItems({
    String? quoteId,
    String? proformaId,
    required List<dynamic> items,
  }) async {
    if (quoteId != null) {
      await (_db.delete(
        _db.quoteItems,
      )..where((i) => i.quoteId.equals(quoteId))).go();
      for (final raw in items) {
        final item = raw as Map<String, dynamic>;
        await _db.into(_db.quoteItems).insertOnConflictUpdate(
          QuoteItemsCompanion(
            id: Value(item['id'] as String),
            quoteId: Value(quoteId),
            description: Value(item['description'] as String),
            quantity: Value((item['quantity'] as num).toInt()),
            unit: Value(item['unit'] as String? ?? 'adet'),
            unitPriceMinor: Value((item['unit_price_minor'] as num).toInt()),
            taxRate: Value((item['tax_rate'] as num?)?.toInt() ?? 20),
            discountMinor: Value((item['discount_minor'] as num?)?.toInt() ?? 0),
          ),
        );
      }
      return;
    }
    await (_db.delete(
      _db.proformaItems,
    )..where((i) => i.proformaId.equals(proformaId!))).go();
    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      await _db.into(_db.proformaItems).insertOnConflictUpdate(
        ProformaItemsCompanion(
          id: Value(item['id'] as String),
          proformaId: Value(proformaId!),
          description: Value(item['description'] as String),
          quantity: Value((item['quantity'] as num).toInt()),
          unit: Value(item['unit'] as String? ?? 'adet'),
          unitPriceMinor: Value((item['unit_price_minor'] as num).toInt()),
          taxRate: Value((item['tax_rate'] as num?)?.toInt() ?? 20),
          discountMinor: Value((item['discount_minor'] as num?)?.toInt() ?? 0),
        ),
      );
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
