import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import 'notification_service.dart';

/// Uygulama arka plandayken/kapalıyken gelen mesajlar için üst düzey
/// işleyici. Android bu işleyiciyi ayrı bir isolate'te çağırır — bu yüzden
/// üst düzey (top-level) bir fonksiyon OLMAK ZORUNDA.
///
/// Bildirimin kendisini Android sistem tepsisine FCM'in kendisi düşürür
/// (mesajda `notification` bloğu var); burada ekstra bir şey göstermeye
/// gerek yok, aksi halde bildirim iki kez görünürdü.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Kasıtlı olarak boş: yalnızca isolate'in ayakta olması yeterli.
}

/// Sunucu tarafı push bildirimleri (FCM) — bkz. docs/06 § Push Notification.
///
/// Sorumluluk: izin iste, cihaz token'ını al, backend'e kaydet, ön planda
/// gelen mesajı yerel bildirim olarak göster. Token yenilendiğinde tekrar
/// kaydeder. Firebase yapılandırması yoksa (ör. test/CI) sessizce devre
/// dışı kalır — uygulama asla bu yüzden çökmez.
class PushService {
  PushService(this._api);

  final ApiClient _api;

  bool _initialized = false;
  String? _registeredToken;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Oturum açıldıktan SONRA çağrılmalı — token backend'e kaydedilirken
  /// kimlik doğrulaması gerekir.
  Future<void> start() async {
    if (_initialized) {
      // Zaten başlatıldıysa yalnızca token'ı (yeniden) kaydet: kullanıcı
      // değişmiş olabilir.
      await _registerCurrentToken(force: true);
      return;
    }

    try {
      await Firebase.initializeApp();

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      _foregroundSub = FirebaseMessaging.onMessage.listen(_showForeground);
      _tokenRefreshSub = messaging.onTokenRefresh.listen((token) {
        unawaited(_sendTokenToBackend(token));
      });
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      _initialized = true;
      await _registerCurrentToken();
    } catch (error) {
      // Firebase kurulu değil / cihazda Play Services yok / ağ yok —
      // push olmadan uygulama tam çalışmaya devam eder.
      debugPrint('Push başlatılamadı: $error');
    }
  }

  Future<void> _registerCurrentToken({bool force = false}) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      if (!force && token == _registeredToken) return;
      await _sendTokenToBackend(token);
    } catch (error) {
      debugPrint('Push token alınamadı: $error');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await _api.dio.post(
        '/devices',
        data: {'token': token, 'platform': 'android'},
      );
      _registeredToken = token;
    } catch (error) {
      // Çevrimdışıysa bir sonraki `start()` (uygulama açılışı) tekrar dener.
      debugPrint('Push token kaydedilemedi: $error');
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await NotificationService.showNow(
      // Aynı mesajın iki kez gösterilmemesi için kararlı bir id.
      id: message.messageId.hashCode & 0x7fffffff,
      title: notification.title ?? 'TeknikCEP',
      body: notification.body ?? '',
    );
  }

  /// Çıkışta çağrılır — bu cihaz artık eski hesabın bildirimlerini almamalı.
  Future<void> unregister() async {
    final token = _registeredToken;
    _registeredToken = null;
    if (token == null) return;
    try {
      await _api.dio.delete('/devices', data: {'token': token});
    } catch (error) {
      debugPrint('Push kaydı silinemedi: $error');
    }
  }

  void dispose() {
    _foregroundSub?.cancel();
    _tokenRefreshSub?.cancel();
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref.watch(apiClientProvider));
  ref.onDispose(service.dispose);
  return service;
});
