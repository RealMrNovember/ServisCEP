import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/diagnostics/crash_reporter.dart';
import 'core/services/notification_service.dart';
import 'core/sync/background_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hata yakalayicilar EN BASTA kuruluyor: asagidaki hazirlik
  // adimlarindan birinde patlarsa da kayit altina alinsin. Uygulamada
  // hicbir global yakalayici yoktu; cizim sirasinda olusan bir hata
  // yalnizca cihazin konsoluna yaziliyor ve orada kaliyordu.
  CrashReporter.install();
  await CrashReporter.prepare();

  await initializeDateFormatting('tr_TR');
  await NotificationService.init();
  // Uygulama kapaliyken de bekleyen yazmalar gonderilsin diye periyodik
  // arka plan gorevi kaydedilir; hata durumunda sessizce vazgecer.
  await registerBackgroundSync();

  runApp(const ProviderScope(child: TeknikCepApp()));

  // Bekleyen hata kayitlari acilistan SONRA gonderiliyor ve beklenmiyor:
  // tanilama gondermek uygulamanin acilisini geciktirmemeli.
  unawaited(CrashReporter.flush());
}
