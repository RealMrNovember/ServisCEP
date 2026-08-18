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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(products);
        await m.createTable(stockMovements);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'serviscep');
  }
}
