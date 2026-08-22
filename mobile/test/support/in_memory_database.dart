import 'package:drift/native.dart';

import 'package:serviscep/core/database/app_database.dart';

/// Her testte taze, bellek içi bir veritabanı — testler birbirini
/// etkilemez.
AppDatabase createInMemoryDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}
