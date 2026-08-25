import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Companies,
    Users,
    Customers,
    JobTypes,
    ServiceRequests,
    Jobs,
    JobNotes,
    JobPhotos,
    JobSignatures,
    Quotes,
    QuoteItems,
    Proformas,
    ProformaItems,
    Payments,
    IncomeEntries,
    ExpenseEntries,
    CustomerLedgerEntries,
    Products,
    StockMovements,
    SyncOperations,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Testler için — gerçek (ama bellek içi) bir `NativeDatabase` verilir,
  /// `drift_flutter`'ın platform kanalı gerektiren `driftDatabase()`'ine
  /// gidilmez.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(products);
        await m.createTable(stockMovements);
      }
      if (from < 3) {
        // Tek "name" alanı yetkili adı/firma adı olarak ikiye ayrıldı
        // (bkz. docs/02). Mevcut kayıtlar veri kaybı olmadan taşınır: FIRMA
        // tipindeki müşterilerde eski isim firma adına, diğerlerinde
        // yetkili adına gider.
        await m.addColumn(customers, customers.contactName);
        await m.addColumn(customers, customers.companyName);
        await m.addColumn(customers, customers.iban);
        await customStatement(
          "UPDATE customers SET company_name = name WHERE type = 'FIRMA'",
        );
        await customStatement(
          "UPDATE customers SET contact_name = name WHERE type != 'FIRMA'",
        );
        await m.dropColumn(customers, 'name');
      }
      if (from < 4) {
        // Senkron motoru (bkz. ROADMAP.md § B10) — backend'in version tabanlı
        // optimistic concurrency'sinin yerel karşılığı + outbox kuyruğu.
        await m.addColumn(customers, customers.version);
        await m.addColumn(jobs, jobs.version);
        await m.createTable(syncOperations);
      }
      if (from < 5) {
        // Senkron kapsam genişletmesi (dikey dilim 2): ServiceRequest,
        // Quote ve Proforma da versiyonlu senkrona katılıyor.
        await m.addColumn(serviceRequests, serviceRequests.version);
        await m.addColumn(quotes, quotes.syncStatus);
        await m.addColumn(quotes, quotes.version);
        await m.addColumn(proformas, proformas.syncStatus);
        await m.addColumn(proformas, proformas.version);
      }
      if (from < 6) {
        // Vergi levhası (müşteri belgesi) — web panelindeki
        // tax_certificate_path alanının mobil karşılığı.
        await m.addColumn(customers, customers.taxCertificatePath);
        await m.addColumn(customers, customers.hasTaxCertificate);
      }
      if (from < 7) {
        // Cari hesap artık sunucuyla senkronlanıyor; mevcut yerel
        // kayıtlar iyimser (PENDING) sayılır ve ilk pull'da sunucudaki
        // karşılıklarıyla değiştirilir.
        await m.addColumn(
          customerLedgerEntries,
          customerLedgerEntries.syncStatus,
        );
      }
      if (from < 8) {
        // Kurumsal belge alanları: antet bilgileri, logolar, para birimi
        // ve KDV kipi (bkz. docs/03 § PDF Motoru).
        await m.addColumn(companies, companies.address);
        await m.addColumn(companies, companies.phone);
        await m.addColumn(companies, companies.email);
        await m.addColumn(companies, companies.taxInfo);
        await m.addColumn(companies, companies.hasLogo);
        await m.addColumn(customers, customers.logoPath);
        await m.addColumn(customers, customers.hasLogo);
        for (final column in [
          quotes.currency,
          quotes.vatMode,
          quotes.vatRate,
          quotes.validUntil,
        ]) {
          await m.addColumn(quotes, column);
        }
        for (final column in [
          proformas.currency,
          proformas.vatMode,
          proformas.vatRate,
        ]) {
          await m.addColumn(proformas, column);
        }
      }
      if (from < 9) {
        // Belge metinleri: giris yazisi ve sartlar. Hem sirket
        // varsayilani hem belge kopyasi olarak tutulur.
        for (final column in [
          companies.introText,
          companies.paymentTerms,
          companies.deliveryTime,
          companies.warrantyTerms,
        ]) {
          await m.addColumn(companies, column);
        }
        for (final column in [
          quotes.introText,
          quotes.paymentTerms,
          quotes.deliveryTime,
          quotes.warrantyTerms,
        ]) {
          await m.addColumn(quotes, column);
        }
        for (final column in [
          proformas.introText,
          proformas.paymentTerms,
          proformas.deliveryTime,
          proformas.warrantyTerms,
        ]) {
          await m.addColumn(proformas, column);
        }
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'serviscep');
  }
}
