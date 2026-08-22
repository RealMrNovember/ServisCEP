import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/core_providers.dart';
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
      await _db.update(_db.customers).replace(customer);
      await _enqueue(
        entityId: customer.id,
        operation: 'UPDATE',
        baseVersion: customer.version,
        payload: {
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
        },
      );
    });
  }

  Future<void> softDelete(String id) async {
    await _db.transaction(() async {
      await (_db.update(_db.customers)..where((c) => c.id.equals(id))).write(
        CustomersCompanion(deletedAt: Value(DateTime.now())),
      );
      await _enqueue(entityId: id, operation: 'DELETE', payload: const {});
    });
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
