import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/session_controller.dart';
import 'sync_service.dart';

const _periodicSyncInterval = Duration(minutes: 3);

/// Bağlantı geldiğinde / uygulama öne geldiğinde / periyodik olarak
/// `SyncService.runOnce()`'u tetikler. Oturum yoksa (henüz giriş
/// yapılmamışsa) hiçbir şey yapmaz.
class SyncTrigger with WidgetsBindingObserver {
  SyncTrigger(this._ref);

  final Ref _ref;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicTimer;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) _trigger();
    });
    _periodicTimer = Timer.periodic(_periodicSyncInterval, (_) => _trigger());
    _trigger();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _trigger();
  }

  void _trigger() {
    final session = _ref.read(sessionControllerProvider).valueOrNull;
    if (session == null) return;
    unawaited(_ref.read(syncServiceProvider).runOnce(session.companyId));
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _periodicTimer?.cancel();
  }
}

/// `ref.watch`/`ref.read` edildiği an bir kere başlar (Provider create
/// callback'i yalnızca ilk okumada çalışır) — bkz. `app.dart`.
final syncTriggerProvider = Provider<SyncTrigger>((ref) {
  final trigger = SyncTrigger(ref)..start();
  ref.onDispose(trigger.dispose);
  return trigger;
});
