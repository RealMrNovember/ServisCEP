import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/sync/sync_trigger.dart';
import 'router.dart';
import 'theme.dart';

class ServisCepApp extends ConsumerWidget {
  const ServisCepApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Bağlantı/app-resume/periyodik senkron tetikleyicisini başlatır —
    // oturum yoksa no-op kalır (bkz. SyncTrigger._trigger).
    ref.watch(syncTriggerProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'ServisCEP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
