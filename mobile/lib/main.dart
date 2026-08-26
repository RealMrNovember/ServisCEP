import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/services/notification_service.dart';
import 'core/sync/background_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  await NotificationService.init();
  // Uygulama kapaliyken de bekleyen yazmalar gonderilsin diye periyodik
  // arka plan gorevi kaydedilir; hata durumunda sessizce vazgecer.
  await registerBackgroundSync();
  runApp(const ProviderScope(child: TeknikCepApp()));
}
