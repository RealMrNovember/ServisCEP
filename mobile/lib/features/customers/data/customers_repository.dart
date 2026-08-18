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
    return (_db.select(_db.customers)..where((c) => c.id.equals(id))).getSingleOrNull();
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
      (contactName?.trim().isNotEmpty ?? false) || (companyName?.trim().isNotEmpty ?? false),
      'Yetkili adı soyadı veya firma adından en az biri dolu olmalı',
    );
    final countThisYear = await (_db.select(_db.customers)
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
    await _db.into(_db.customers).insert(companion);
    return (await byId(id))!;
  }

  Future<void> update(Customer customer) {
    return _db.update(_db.customers).replace(customer);
  }

  Future<void> softDelete(String id) {
    return (_db.update(_db.customers)..where((c) => c.id.equals(id))).write(
      CustomersCompanion(deletedAt: Value(DateTime.now())),
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
