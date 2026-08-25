import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/sync_api_client.dart';
import '../../../core/providers/core_providers.dart';

/// Sunucudaki bekleyen bir senkron çakışması — telefonun göndermeye
/// çalıştığı hal ile sunucudaki halin karşılaştırılabilir özeti.
class PendingConflict {
  PendingConflict({
    required this.id,
    required this.subjectType,
    required this.subjectId,
    required this.baseVersion,
    required this.serverVersion,
    required this.incomingPayload,
    required this.serverSnapshot,
    required this.createdAt,
  });

  factory PendingConflict.fromJson(Map<String, dynamic> json) {
    return PendingConflict(
      id: json['id'] as String,
      subjectType: json['subject_type'] as String,
      subjectId: json['subject_id'] as String,
      baseVersion: (json['base_version'] as num?)?.toInt() ?? 0,
      serverVersion: (json['server_version'] as num?)?.toInt() ?? 0,
      incomingPayload:
          (json['incoming_payload'] as Map?)?.cast<String, dynamic>() ?? {},
      serverSnapshot:
          (json['server_snapshot'] as Map?)?.cast<String, dynamic>() ?? {},
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  final String id;
  final String subjectType;
  final String subjectId;
  final int baseVersion;
  final int serverVersion;
  final Map<String, dynamic> incomingPayload;
  final Map<String, dynamic> serverSnapshot;
  final DateTime? createdAt;

  String get subjectLabel => switch (subjectType) {
    'customer' => 'Müşteri',
    'job' => 'İş',
    'service_request' => 'Talep',
    'quote' => 'Teklif',
    'proforma' => 'Proforma',
    _ => subjectType,
  };

  /// Yalnızca GERÇEKTEN farklı olan alanlar — kullanıcıya 20 satırlık ham
  /// JSON yerine "neyi seçiyorum" sorusunun cevabı gösterilir.
  List<ConflictFieldDiff> get differences {
    final keys = {...incomingPayload.keys, ...serverSnapshot.keys}
      ..removeWhere((k) => k == 'id' || k == 'base_version' || k == 'version');
    final diffs = <ConflictFieldDiff>[];
    for (final key in keys) {
      final mine = incomingPayload[key];
      final server = serverSnapshot[key];
      if (_normalize(mine) == _normalize(server)) continue;
      diffs.add(
        ConflictFieldDiff(
          field: key,
          mine: _display(mine),
          server: _display(server),
        ),
      );
    }
    diffs.sort((a, b) => a.field.compareTo(b.field));
    return diffs;
  }

  static String _normalize(Object? value) =>
      value == null ? '' : value.toString().trim();

  static String _display(Object? value) {
    final text = _normalize(value);
    return text.isEmpty ? '—' : text;
  }
}

class ConflictFieldDiff {
  const ConflictFieldDiff({
    required this.field,
    required this.mine,
    required this.server,
  });

  final String field;
  final String mine;
  final String server;

  /// Alan adlarının okunabilir karşılıkları — backend payload'ı snake_case
  /// gönderir, kullanıcı "contact_name" görmemeli.
  String get label => switch (field) {
    'contact_name' => 'Yetkili adı',
    'company_name' => 'Firma adı',
    'phone' => 'Telefon',
    'email' => 'E-posta',
    'address' => 'Adres',
    'il' => 'İl',
    'ilce' => 'İlçe',
    'tax_info' => 'Vergi bilgisi',
    'iban' => 'IBAN',
    'notes' => 'Notlar',
    'tags' => 'Etiketler',
    'type' => 'Tür',
    'code' => 'Kod',
    'title' => 'Başlık',
    'description' => 'Açıklama',
    'status' => 'Durum',
    'priority' => 'Öncelik',
    'notes_' => 'Notlar',
    'estimated_price_minor' => 'Tahmini tutar',
    'actual_price_minor' => 'Gerçekleşen tutar',
    'appointment_date' => 'Randevu tarihi',
    _ => field,
  };
}

class SyncConflictRepository {
  SyncConflictRepository(this._api, this._db);

  final SyncApiClient _api;
  final AppDatabase _db;

  Future<List<PendingConflict>> fetchPending() async {
    final raw = await _api.listPendingConflicts();
    return raw.map(PendingConflict.fromJson).toList();
  }

  /// Çakışmayı sunucuda çözer ve YEREL izleri temizler: çakışan outbox
  /// satırı silinir (artık anlamı yok — karar verildi), kaydın durumu
  /// PENDING'e alınır ki bir sonraki pull sunucunun nihai halini yerele
  /// yazsın (her iki seçenekte de doğru hal sunucudadır).
  Future<void> resolve(PendingConflict conflict, String resolution) async {
    await _api.resolveConflict(conflict.id, resolution);

    await _db.transaction(() async {
      await (_db.delete(_db.syncOperations)..where(
            (o) =>
                o.entityId.equals(conflict.subjectId) &
                o.status.equals('CONFLICT'),
          ))
          .go();
      await _clearEntityConflictFlag(conflict.subjectType, conflict.subjectId);
    });
  }

  Future<void> _clearEntityConflictFlag(String type, String id) async {
    const synced = Value('SYNCED');
    switch (type) {
      case 'customer':
        await (_db.update(_db.customers)..where((c) => c.id.equals(id))).write(
          const CustomersCompanion(syncStatus: synced),
        );
      case 'job':
        await (_db.update(_db.jobs)..where((j) => j.id.equals(id))).write(
          const JobsCompanion(syncStatus: synced),
        );
      case 'service_request':
        await (_db.update(_db.serviceRequests)..where((r) => r.id.equals(id)))
            .write(const ServiceRequestsCompanion(syncStatus: synced));
      case 'quote':
        await (_db.update(_db.quotes)..where((q) => q.id.equals(id))).write(
          const QuotesCompanion(syncStatus: synced),
        );
      case 'proforma':
        await (_db.update(_db.proformas)..where((p) => p.id.equals(id))).write(
          const ProformasCompanion(syncStatus: synced),
        );
    }
  }
}

final syncConflictRepositoryProvider = Provider<SyncConflictRepository>((ref) {
  return SyncConflictRepository(
    ref.watch(syncApiClientProvider),
    ref.watch(databaseProvider),
  );
});

final pendingConflictsProvider = FutureProvider<List<PendingConflict>>((ref) {
  return ref.watch(syncConflictRepositoryProvider).fetchPending();
});

/// "Daha Fazla" ekranındaki rozet — yerelde CONFLICT işaretli kayıt sayısı.
/// Yerelden okunur ki çevrimdışıyken de doğru görünsün.
final localConflictCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.selectOnly(db.syncOperations)
    ..addColumns([db.syncOperations.id])
    ..where(db.syncOperations.status.equals('CONFLICT'));
  return query.watch().map((rows) => rows.length);
});
