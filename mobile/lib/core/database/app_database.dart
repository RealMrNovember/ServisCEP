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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

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
        await customStatement("UPDATE customers SET company_name = name WHERE type = 'FIRMA'");
        await customStatement("UPDATE customers SET contact_name = name WHERE type != 'FIRMA'");
        await m.dropColumn(customers, 'name');
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'serviscep');
  }
}
