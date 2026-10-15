import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/doc_item_draft.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/sync/changed_fields.dart';
import '../../../core/utils/document_numbering.dart';
import '../../../core/utils/money.dart';
import '../../auth/data/session_controller.dart';

class ProformaWithCustomer {
  ProformaWithCustomer(this.proforma, this.customer);
  final Proforma proforma;
  final Customer customer;
}

/// Proforma modülü — bkz. docs/03 § Proforma Modülü.
class ProformasRepository {
  ProformasRepository(this._db);
  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<ProformaWithCustomer>> watchAll(String companyId) {
    final query =
        _db.select(_db.proformas).join([
            innerJoin(
              _db.customers,
              _db.customers.id.equalsExp(_db.proformas.customerId),
            ),
          ])
          ..where(_db.proformas.companyId.equals(companyId))
          ..orderBy([OrderingTerm.desc(_db.proformas.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => ProformaWithCustomer(
              r.readTable(_db.proformas),
              r.readTable(_db.customers),
            ),
          )
          .toList(),
    );
  }

  Future<Proforma?> byId(String id) {
    return (_db.select(
      _db.proformas,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Stream<List<ProformaItem>> watchItems(String proformaId) {
    return (_db.select(
      _db.proformaItems,
    )..where((i) => i.proformaId.equals(proformaId))).watch();
  }

  /// Yeni proforma. Toplam, KDV kipini hesaba katan ortak hesap motoruyla
  /// bulunur (bkz. core/utils/money.dart) — teklifle aynı kod yolundan
  /// geçmesi, iki belgenin aynı kalemler için farklı tutar göstermesini
  /// engeller.
  /// Sıradaki belge numarası — bkz. [DocumentNumbering].
  Future<String> nextCode(String companyId) async {
    final codes =
        await (_db.selectOnly(_db.proformas)
              ..addColumns([_db.proformas.code])
              ..where(_db.proformas.companyId.equals(companyId)))
            .map((row) => row.read(_db.proformas.code)!)
            .get();
    return DocumentNumbering.next(fallbackPrefix: 'PRF', existingCodes: codes);
  }

  Future<bool> isCodeTaken(String companyId, String code) async {
    final existing =
        await (_db.select(_db.proformas)..where(
              (p) => p.companyId.equals(companyId) & p.code.equals(code.trim()),
            ))
            .get();
    return existing.isNotEmpty;
  }

  Stream<Proforma?> watchById(String id) {
    return (_db.select(
      _db.proformas,
    )..where((p) => p.id.equals(id))).watchSingleOrNull();
  }

  Future<List<ProformaItem>> itemsOf(String proformaId) {
    return (_db.select(
      _db.proformaItems,
    )..where((i) => i.proformaId.equals(proformaId))).get();
  }

  Future<Proforma> create({
    required String companyId,
    required String customerId,
    required List<DocItemDraft> items,
    DateTime? validUntil,
    String? notes,
    String? introText,
    String? paymentTerms,
    String? deliveryTime,
    String? warrantyTerms,
    Currency currency = Currency.try_,
    VatMode vatMode = VatMode.excluded,
    int vatRate = 20,
    String? requestedCode,
  }) async {
    final code = requestedCode?.trim().isNotEmpty == true
        ? requestedCode!.trim()
        : await nextCode(companyId);
    final id = _uuid.v4();
    final total = DocumentTotals.from(
      items.map((item) => item.amounts(vatMode)),
    ).grossMinor;

    await _db.transaction(() async {
      await _db
          .into(_db.proformas)
          .insert(
            ProformasCompanion.insert(
              id: id,
              companyId: companyId,
              code: code,
              customerId: customerId,
              validUntil: Value(validUntil),
              notes: Value(notes),
              introText: Value(introText),
              paymentTerms: Value(paymentTerms),
              deliveryTime: Value(deliveryTime),
              warrantyTerms: Value(warrantyTerms),
              totalMinor: Value(total),
              currency: Value(currency.code),
              vatMode: Value(vatMode.code),
              vatRate: Value(vatRate),
            ),
          );
      final itemPayloads = <Map<String, dynamic>>[];
      for (final item in items) {
        final itemId = _uuid.v4();
        await _db
            .into(_db.proformaItems)
            .insert(
              ProformaItemsCompanion.insert(
                id: itemId,
                proformaId: id,
                description: item.description,
                quantity: Value(item.quantity),
                unit: Value(item.unit),
                unitPriceMinor: Value(item.unitPriceMinor),
                taxRate: Value(item.taxRate),
                discountMinor: Value(item.discountMinor),
              ),
            );
        itemPayloads.add({
          'id': itemId,
          'description': item.description,
          'quantity': item.quantity,
          'unit': item.unit,
          'unit_price_minor': item.unitPriceMinor,
          'tax_rate': item.taxRate,
          'discount_minor': item.discountMinor,
        });
      }
      await _db
          .into(_db.syncOperations)
          .insert(
            SyncOperationsCompanion.insert(
              id: _uuid.v4(),
              entityType: 'proforma',
              entityId: id,
              operation: 'CREATE',
              payload: jsonEncode({
                'id': id,
                'code': code,
                'customer_id': customerId,
                'valid_until': validUntil?.toIso8601String(),
                'notes': notes,
                'intro_text': introText,
                'payment_terms': paymentTerms,
                'delivery_time': deliveryTime,
                'warranty_terms': warrantyTerms,
                'currency': currency.code,
                'vat_mode': vatMode.code,
                'vat_rate': vatRate,
                'items': itemPayloads,
              }),
            ),
          );
    });

    return (await byId(id))!;
  }

  /// Olusmus bir belgeyi gunceller.
  ///
  /// Kalemler TOPLUCA degistiriliyor: gelen liste kaydin yeni hali,
  /// eklenti degil. Tek tek eslestirmek silinen kalemi tespit etmek icin
  /// ayri bir iz gerektirirdi ve oyle bir iz tutulmuyor. Sunucu tarafi da
  /// ayni kurali uyguluyor (bkz. backend ProformaController::update).
  ///
  /// `changed_fields` icinde `total_minor` HER ZAMAN bildiriliyor.
  /// Sunucunun alan bazli birlestirmesi (bkz. DetectsSyncConflicts) ayri
  /// bir tablodaki kalemleri goremez; kalem degisikligi sunucuda yalnizca
  /// `total_minor` olarak iz birakir. Ayni alani burada da bildirmek,
  /// ofiste yapilmis bir kalem degisikliginin sessizce ezilmesi yerine
  /// kullaniciya cakisma olarak gosterilmesini saglar. Tutar degismemis
  /// olsa bile bildiriliyor: fazladan bir cakisma ekrani, kaybolan bir
  /// duzenlemeden iyidir.
  Future<Proforma> update({
    required String id,
    required List<DocItemDraft> items,
    DateTime? validUntil,
    String? notes,
    String? introText,
    String? paymentTerms,
    String? deliveryTime,
    String? warrantyTerms,
    Currency currency = Currency.try_,
    VatMode vatMode = VatMode.excluded,
    int vatRate = 20,
  }) async {
    final total = DocumentTotals.from(
      items.map((item) => item.amounts(vatMode)),
    ).grossMinor;
    // Duzenlemenin GERCEK ani. Cihaz offline ise bu kayit gunler sonra
    // senkron olabilir; sunucuya kendi saatini yazdirmak o ani
    // kaybettirirdi (bkz. backend edited_at gocu).
    final editedAt = DateTime.now();

    await _db.transaction(() async {
      final mevcut = await (_db.select(
        _db.proformas,
      )..where((p) => p.id.equals(id))).getSingle();

      // Baslik alanlarinin farki deponun kendi yardimcisiyla cikariliyor
      // (bkz. degisenAlanlar) — ayni esleme hem eski hem yeni kayda
      // uygulanmazsa fark hesabi anlamsiz olur.
      final eskiBaslik = _baslikYuk(
        validUntil: mevcut.validUntil,
        notes: mevcut.notes,
        introText: mevcut.introText,
        paymentTerms: mevcut.paymentTerms,
        deliveryTime: mevcut.deliveryTime,
        warrantyTerms: mevcut.warrantyTerms,
        currency: mevcut.currency,
        vatMode: mevcut.vatMode,
        vatRate: mevcut.vatRate,
      );
      final yeniBaslik = _baslikYuk(
        validUntil: validUntil,
        notes: notes,
        introText: introText,
        paymentTerms: paymentTerms,
        deliveryTime: deliveryTime,
        warrantyTerms: warrantyTerms,
        currency: currency.code,
        vatMode: vatMode.code,
        vatRate: vatRate,
      );

      // `total_minor` ve `edited_at` HER ZAMAN bildiriliyor — gerekcesi
      // metodun basindaki aciklamada.
      final degisenler = <String>[
        ...degisenAlanlar(eskiBaslik, yeniBaslik),
        'total_minor',
        'edited_at',
      ];

      await (_db.update(_db.proformas)..where((p) => p.id.equals(id))).write(
        ProformasCompanion(
          validUntil: Value(validUntil),
          notes: Value(notes),
          introText: Value(introText),
          paymentTerms: Value(paymentTerms),
          deliveryTime: Value(deliveryTime),
          warrantyTerms: Value(warrantyTerms),
          totalMinor: Value(total),
          currency: Value(currency.code),
          vatMode: Value(vatMode.code),
          vatRate: Value(vatRate),
          editedAt: Value(editedAt),
          syncStatus: const Value('PENDING'),
        ),
      );

      await (_db.delete(
        _db.proformaItems,
      )..where((i) => i.proformaId.equals(id))).go();

      final itemPayloads = <Map<String, dynamic>>[];
      for (final item in items) {
        final itemId = _uuid.v4();
        await _db
            .into(_db.proformaItems)
            .insert(
              ProformaItemsCompanion.insert(
                id: itemId,
                proformaId: id,
                description: item.description,
                quantity: Value(item.quantity),
                unit: Value(item.unit),
                unitPriceMinor: Value(item.unitPriceMinor),
                taxRate: Value(item.taxRate),
                discountMinor: Value(item.discountMinor),
              ),
            );
        itemPayloads.add({
          'id': itemId,
          'description': item.description,
          'quantity': item.quantity,
          'unit': item.unit,
          'unit_price_minor': item.unitPriceMinor,
          'tax_rate': item.taxRate,
          'discount_minor': item.discountMinor,
        });
      }

      await _db
          .into(_db.syncOperations)
          .insert(
            SyncOperationsCompanion.insert(
              id: _uuid.v4(),
              entityType: 'proforma',
              entityId: id,
              operation: 'UPDATE',
              baseVersion: Value(mevcut.version),
              payload: jsonEncode({
                'valid_until': validUntil?.toIso8601String(),
                'notes': notes,
                'intro_text': introText,
                'payment_terms': paymentTerms,
                'delivery_time': deliveryTime,
                'warranty_terms': warrantyTerms,
                'currency': currency.code,
                'vat_mode': vatMode.code,
                'vat_rate': vatRate,
                'edited_at': editedAt.toIso8601String(),
                'items': itemPayloads,
                'changed_fields': degisenler,
              }),
            ),
          );
    });

    return (await byId(id))!;
  }

  /// Sunucuya gonderilen BASLIK alanlari.
  ///
  /// Ayri bir metot olmasi sart: ayni esleme hem eski hem yeni kayda
  /// uygulanmazsa fark hesabi anlamsiz olur (bkz. CustomersRepository).
  Map<String, dynamic> _baslikYuk({
    required DateTime? validUntil,
    required String? notes,
    required String? introText,
    required String? paymentTerms,
    required String? deliveryTime,
    required String? warrantyTerms,
    required String currency,
    required String vatMode,
    required int vatRate,
  }) => {
    'valid_until': validUntil?.toIso8601String(),
    'notes': notes,
    'intro_text': introText,
    'payment_terms': paymentTerms,
    'delivery_time': deliveryTime,
    'warranty_terms': warrantyTerms,
    'currency': currency,
    'vat_mode': vatMode,
    'vat_rate': vatRate,
  };
}

final proformasRepositoryProvider = Provider<ProformasRepository>((ref) {
  return ProformasRepository(ref.watch(databaseProvider));
});

final proformasListProvider = StreamProvider<List<ProformaWithCustomer>>((ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  if (session == null) return const Stream.empty();
  return ref.watch(proformasRepositoryProvider).watchAll(session.companyId);
});

final proformaItemsProvider = StreamProvider.family<List<ProformaItem>, String>(
  (ref, proformaId) {
    return ref.watch(proformasRepositoryProvider).watchItems(proformaId);
  },
);

final proformaByIdProvider = StreamProvider.family<Proforma?, String>((
  ref,
  id,
) {
  return ref.watch(proformasRepositoryProvider).watchById(id);
});
