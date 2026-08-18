import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/session_controller.dart';
import '../database/app_database.dart';
import 'core_providers.dart';

final currentCompanyProvider = FutureProvider<Company?>((ref) async {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  if (session == null) return null;
  final db = ref.watch(databaseProvider);
  return (db.select(db.companies)..where((c) => c.id.equals(session.companyId))).getSingleOrNull();
});
