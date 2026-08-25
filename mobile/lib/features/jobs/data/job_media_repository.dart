import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/core_providers.dart';

/// Servis formu ekleri: fotoğraf, imza, not — bkz. docs/03 § Servis Formu,
/// § Fotoğraf Sistemi, § Dijital İmza.
///
/// Dosyalar uygulamanın kendi belge dizinine kaydedilir (Android'de diğer
/// uygulamalardan erişilemez) — bkz. docs/09 § Dosya Güvenliği ilkesiyle
/// aynı ruh: dosyalar public bir konumda tutulmaz.
class JobMediaRepository {
  JobMediaRepository(this._db);
  final AppDatabase _db;
  final _uuid = const Uuid();

  Future<Directory> _mediaDir(String subfolder) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'serviscep_media', subfolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Stream<List<JobPhoto>> watchPhotos(String jobId) {
    return (_db.select(_db.jobPhotos)
          ..where((ph) => ph.jobId.equals(jobId))
          ..orderBy([(ph) => OrderingTerm.desc(ph.createdAt)]))
        .watch();
  }

  Future<JobPhoto> addPhoto({
    required String jobId,
    required String sourcePath,
    required String category,
  }) async {
    final dir = await _mediaDir('photos');
    final ext = p.extension(sourcePath);
    final id = _uuid.v4();
    final destPath = p.join(dir.path, '$id$ext');
    await File(sourcePath).copy(destPath);

    await _db.transaction(() async {
      await _db
          .into(_db.jobPhotos)
          .insert(
            JobPhotosCompanion.insert(
              id: id,
              jobId: jobId,
              category: Value(category),
              filePath: destPath,
            ),
          );
      await _enqueue(
        entityType: 'job_photo',
        entityId: id,
        payload: {
          'id': id,
          'job_id': jobId,
          'category': category,
          'file_path': destPath,
        },
      );
    });
    return (_db.select(
      _db.jobPhotos,
    )..where((ph) => ph.id.equals(id))).getSingle();
  }

  Stream<List<JobSignature>> watchSignatures(String jobId) {
    return (_db.select(
      _db.jobSignatures,
    )..where((s) => s.jobId.equals(jobId))).watch();
  }

  Future<JobSignature> addSignature({
    required String jobId,
    required String signerName,
    required List<int> pngBytes,
  }) async {
    final dir = await _mediaDir('signatures');
    final id = _uuid.v4();
    final destPath = p.join(dir.path, '$id.png');
    await File(destPath).writeAsBytes(pngBytes);

    await _db.transaction(() async {
      await _db
          .into(_db.jobSignatures)
          .insert(
            JobSignaturesCompanion.insert(
              id: id,
              jobId: jobId,
              signerName: signerName,
              filePath: destPath,
            ),
          );
      await _enqueue(
        entityType: 'job_signature',
        entityId: id,
        payload: {
          'id': id,
          'job_id': jobId,
          'signer_name': signerName,
          'file_path': destPath,
        },
      );
    });
    return (_db.select(
      _db.jobSignatures,
    )..where((s) => s.id.equals(id))).getSingle();
  }

  Stream<List<JobNote>> watchNotes(String jobId) {
    return (_db.select(_db.jobNotes)
          ..where((n) => n.jobId.equals(jobId))
          ..orderBy([(n) => OrderingTerm.desc(n.createdAt)]))
        .watch();
  }

  Future<void> addNote({required String jobId, required String note}) async {
    final id = _uuid.v4();
    await _db.transaction(() async {
      await _db
          .into(_db.jobNotes)
          .insert(JobNotesCompanion.insert(id: id, jobId: jobId, note: note));
      await _enqueue(
        entityType: 'job_note',
        entityId: id,
        payload: {'id': id, 'job_id': jobId, 'note': note},
      );
    });
  }

  Future<void> _enqueue({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) {
    return _db
        .into(_db.syncOperations)
        .insert(
          SyncOperationsCompanion.insert(
            id: _uuid.v4(),
            entityType: entityType,
            entityId: entityId,
            operation: 'CREATE',
            payload: jsonEncode(payload),
          ),
        );
  }
}

final jobMediaRepositoryProvider = Provider<JobMediaRepository>((ref) {
  return JobMediaRepository(ref.watch(databaseProvider));
});

final jobPhotosProvider = StreamProvider.family<List<JobPhoto>, String>((
  ref,
  jobId,
) {
  return ref.watch(jobMediaRepositoryProvider).watchPhotos(jobId);
});

final jobSignaturesProvider = StreamProvider.family<List<JobSignature>, String>(
  (ref, jobId) {
    return ref.watch(jobMediaRepositoryProvider).watchSignatures(jobId);
  },
);

final jobNotesProvider = StreamProvider.family<List<JobNote>, String>((
  ref,
  jobId,
) {
  return ref.watch(jobMediaRepositoryProvider).watchNotes(jobId);
});
