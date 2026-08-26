import 'dart:convert';

import '../../../core/sync/changed_fields.dart';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/media_storage.dart';
import '../../../core/utils/code_generator.dart';
import '../../auth/data/session_controller.dart';

class CustomersRepository {
  CustomersRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<Customer>> watchAll(String companyId) {
    return (_db.select(_db.customers)
          ..where((c) => c.companyId.equals(companyId) & c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
        .watch();
  }

  Future<Customer?> byId(String id) {
    return (_db.select(
      _db.customers,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Future<Customer> create({
    required String companyId,
    String? contactName,
    String? companyName,
    String? iban,
    required String type,
    String? phone,
    String? email,
    String? address,
    String? il,
    String? ilce,
    String? taxInfo,
    String? notes,
  }) async {
    assert(
      (contactName?.trim().isNotEmpty ?? false) ||
          (companyName?.trim().isNotEmpty ?? false),
      'Yetkili adı soyadı veya firma adından en az biri dolu olmalı',
    );
    final countThisYear =
        await (_db.select(_db.customers)
              ..where((c) => c.companyId.equals(companyId)))
            .get()
            .then((rows) => rows.length);
    final code = CodeGenerator.next('CUS', countThisYear);
    final id = _uuid.v4();

    final companion = CustomersCompanion.insert(
      id: id,
      companyId: companyId,
      code: code,
      contactName: Value(contactName),
      companyName: Value(companyName),
      iban: Value(iban),
      type: Value(type),
      phone: Value(phone),
      email: Value(email),
      address: Value(address),
      il: Value(il),
      ilce: Value(ilce),
      taxInfo: Value(taxInfo),
      notes: Value(notes),
    );

    await _db.transaction(() async {
      await _db.into(_db.customers).insert(companion);
      await _enqueue(
        entityId: id,
        operation: 'CREATE',
        payload: {
          'id': id,
          'code': code,
          'contact_name': contactName,
          'company_name': companyName,
          'iban': iban,
          'type': type,
          'phone': phone,
          'email': email,
          'address': address,
          'il': il,
          'ilce': ilce,
          'tax_info': taxInfo,
          'notes': notes,
        },
      );
    });
    return (await byId(id))!;
  }

  /// `customer.version`, çağıranın kaydı en son GÖRDÜĞÜ sürümdür (`byId`
  /// ile yüklenip düzenlenip buraya geri verilir) — `base_version` olarak
  /// bu gönderilir, sunucudaki gerçek son sürümle karşılaştırılır.
  Future<void> update(Customer customer) async {
    await _db.transaction(() async {
      // Kaydın ESKİ hâli, üzerine yazmadan ÖNCE okunuyor: sunucuya hangi
      // alanların gerçekten değiştiğini bildirebilmek için tek fırsat
      // burası. Yük kaydın tamamını taşıdığı için sunucu bunu kendi
      // başına çıkaramıyor (bkz. degisenAlanlar).
      final oncesi = await byId(customer.id);
      final yuk = _yuk(customer);

      await _db.update(_db.customers).replace(customer);
      await _enqueue(
        entityId: customer.id,
        operation: 'UPDATE',
        baseVersion: customer.version,
        payload: {
          ...yuk,
          'changed_fields': degisenAlanlar(
            oncesi == null ? null : _yuk(oncesi),
            yuk,
          ),
        },
      );
    });
  }

  /// Sunucuya gönderilen alan kümesi.
  ///
  /// Ayrı bir metot olması şart: aynı eşleme hem yeni hem eski kayda
  /// uygulanmazsa fark hesabı anlamsız olur.
  Map<String, dynamic> _yuk(Customer customer) => {
    'code': customer.code,
    'contact_name': customer.contactName,
    'company_name': customer.companyName,
    'iban': customer.iban,
    'type': customer.type,
    'phone': customer.phone,
    'email': customer.email,
    'address': customer.address,
    'il': customer.il,
    'ilce': customer.ilce,
    'tax_info': customer.taxInfo,
    'notes': customer.notes,
    'tags': customer.tags,
  };

  Future<void> softDelete(String id) async {
    await _db.transaction(() async {
      await (_db.update(_db.customers)..where((c) => c.id.equals(id))).write(
        CustomersCompanion(deletedAt: Value(DateTime.now())),
      );
      await _enqueue(entityId: id, operation: 'DELETE', payload: const {});
    });
  }

  /// Vergi levhası — kamerayla çekilen dosya uygulamanın kendi belge
  /// dizinine kopyalanır (kaynak dosya geçici olabilir) ve yüklemesi
  /// outbox'a düşer. Müşteri başına tek belge: yeni yükleme hem yerelde
  /// hem sunucuda öncekinin yerine geçer.
  Future<void> setTaxCertificate({
    required String customerId,
    required String sourcePath,
  }) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(root.path, 'serviscep_media', 'tax_certificates'),
    );
    if (!await dir.exists()) await dir.create(recursive: true);

    final destPath = p.join(dir.path, '$customerId${p.extension(sourcePath)}');
    await File(sourcePath).copy(destPath);

    await _db.transaction(() async {
      await (_db.update(_db.customers)..where((c) => c.id.equals(customerId)))
          .write(CustomersCompanion(taxCertificatePath: Value(destPath)));
      await _enqueue(
        entityId: customerId,
        operation: 'TAX_CERTIFICATE',
        payload: {'file_path': destPath},
      );
    });
  }

  /// Müşteri logosu — belgede karşı tarafın markası.
  ///
  /// Kırpılmış PNG doğrudan bayt olarak gelir (bkz. LogoCropperScreen);
  /// vergi levhasından farklı olarak burada kaynak dosya kopyalanmaz,
  /// çünkü kırpma zaten yeni bir görsel üretmiştir.
  Future<void> setLogo({
    required String customerId,
    required Uint8List bytes,
  }) async {
    final path = await MediaStorage.writeLogo(
      bucket: 'customer_logos',
      ownerId: customerId,
      bytes: bytes,
      stamp: DateTime.now().millisecondsSinceEpoch,
    );

    await _db.transaction(() async {
      await (_db.update(
        _db.customers,
      )..where((c) => c.id.equals(customerId))).write(
        CustomersCompanion(logoPath: Value(path), hasLogo: const Value(true)),
      );
      await _enqueue(
        entityId: customerId,
        operation: 'LOGO',
        payload: {'file_path': path},
      );
    });
  }

  Future<void> removeLogo(String customerId) async {
    final customer = await byId(customerId);

    await _db.transaction(() async {
      await (_db.update(
        _db.customers,
      )..where((c) => c.id.equals(customerId))).write(
        const CustomersCompanion(logoPath: Value(null), hasLogo: Value(false)),
      );
      // `file_path: null` senkron motoruna "sunucudaki logoyu sil" der.
      await _enqueue(
        entityId: customerId,
        operation: 'LOGO',
        payload: const {'file_path': null},
      );
    });

    await MediaStorage.deleteIfExists(customer?.logoPath);
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
            entityType: 'customer',
            entityId: entityId,
            operation: operation,
            payload: jsonEncode(payload),
            baseVersion: Value(baseVersion),
          ),
        );
  }
}

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return CustomersRepository(ref.watch(databaseProvider));
});

final customersListProvider = StreamProvider<List<Customer>>((ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  if (session == null) return const Stream.empty();
  return ref.watch(customersRepositoryProvider).watchAll(session.companyId);
});

/// Tek müşteri — belge formlarında seçilen müşterinin bilgileri canlı
/// izlenir ki müşteri düzenlendiğinde form da tazelensin.
final customerByIdProvider = StreamProvider.family<Customer?, String>((
  ref,
  id,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.customers,
  )..where((c) => c.id.equals(id))).watchSingleOrNull();
});
