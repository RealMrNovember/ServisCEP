import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/session_controller.dart';
import '../../features/subscription/data/subscription_repository.dart';
import '../services/push_service.dart';
import 'sync_service.dart';
import 'sync_status.dart';

const _periodicSyncInterval = Duration(minutes: 3);

/// Yeni bir yazma kuyruğa düştükten sonra senkronun beklediği süre.
///
/// Sıfır değil: tek bir kullanıcı eylemi (ör. iş kaydı + fotoğrafları)
/// arka arkaya birkaç outbox satırı üretir; hepsi için ayrı tur açmak yerine
/// kısa bir süre toplanıp tek turda gönderilir.
const _outboxDebounceInterval = Duration(seconds: 2);

/// Bağlantı geldiğinde / uygulama öne geldiğinde / periyodik olarak /
/// oturum yeni AÇILDIĞINDA `SyncService.runOnce()`'u tetikler. Oturum
/// yoksa (henüz giriş yapılmamışsa) hiçbir şey yapmaz.
///
/// NOT: `start()` çağrıldığı an `sessionControllerProvider` genelde hâlâ
/// `loading` durumundadır (`SessionController`'ın constructor'daki
/// `_restore()`'u henüz bitmemiştir) — bu yüzden BAŞLANGIÇTAKİ tek seferlik
/// `_trigger()` çağrısı neredeyse her zaman no-op'tur. Asıl güvenilir
/// tetikleyici, oturumun `null`/`loading`'den GERÇEK bir oturuma geçtiği
/// anı yakalayan `ref.listen` — hem "restoreSession tamamlandı" hem
/// "kullanıcı az önce giriş/kayıt oldu" senaryosunu kapsar. Bu olmadan,
/// bir kullanıcı giriş yaptıktan sonra ilk senkron ancak 3 dakikalık
/// periyodik zamanlayıcıyı veya bir bağlantı/resume olayını beklerdi —
/// gerçek kullanıcı testinde "giriş başarılı ama hiçbir veri gelmedi"
/// olarak ortaya çıktı.
class SyncTrigger with WidgetsBindingObserver {
  SyncTrigger(this._ref);

  final Ref _ref;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicTimer;
  Timer? _outboxDebounce;
  String? _lastSyncedUserId;
  int _sonKuyrukSayisi = 0;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) _trigger();
    });
    _periodicTimer = Timer.periodic(_periodicSyncInterval, (_) => _trigger());
    _ref.listen(sessionControllerProvider, (previous, next) {
      final session = next.valueOrNull;
      if (session != null && session.userId != _lastSyncedUserId) {
        _trigger();
        // Push kaydı da oturuma bağlı: token backend'e ancak kimlik
        // doğrulandıktan sonra yazılabilir (bkz. PushService).
        unawaited(_ref.read(pushServiceProvider).start());
      }
      // Çıkışta bildirim kaydını silme işi BİLİNÇLİ olarak burada değil:
      // buraya gelindiğinde oturum jetonu çoktan silinmiş oluyor ve silme
      // isteği 401 alıyordu. Artık SessionController.logout() içinde,
      // jeton hâlâ geçerliyken yapılıyor.
    });

    // YAZMA SONRASI ANINDA SENKRON.
    //
    // Hiçbir repository yazmadan sonra senkron tetiklemiyordu: kullanıcı
    // ÇEVRİMİÇİYKEN bile yeni kaydı 3 dakikalık periyodik tura kadar
    // "gönderilmedi" olarak görüyordu — "otomatik eşitlemedi" şikâyetinin
    // en görünür sebebi buydu. Outbox tablosunu izlemek, sekiz ayrı
    // repository'ye dokunmadan tek noktadan çözer.
    _ref.listen(pendingSyncCountProvider, (previous, next) {
      final sayi = next.valueOrNull;
      if (sayi == null) return;
      final artti = sayi > _sonKuyrukSayisi;
      _sonKuyrukSayisi = sayi;
      if (!artti) return;
      _outboxDebounce?.cancel();
      _outboxDebounce = Timer(_outboxDebounceInterval, _trigger);
    });

    _trigger();
  }

  /// Kalıcı hata almış kayıtları yeniden kuyruğa alır ve hemen bir tur
  /// başlatır. Yeniden denemeye alınan kayıt sayısını döndürür.
  Future<int> retryFailed() async {
    final adet = await _ref.read(syncServiceProvider).retryFailed();
    if (adet > 0) _trigger();
    return adet;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _trigger();
  }

  /// Kullanıcı eylemi sonrası anında senkron (ör. çakışma çözülünce
  /// sunucunun nihai hali hemen inmeli) — periyodik turu beklemeye gerek yok.
  void syncNow() => _trigger();

  /// Elle senkron; SONUCU döner.
  ///
  /// Ekrandaki "Şimdi senkronla" düğmesi eskiden koşulsuz "Senkron
  /// başlatıldı" diyordu — sunucuya hiç ulaşılamadığında bile. Kullanıcıya
  /// olmayan bir başarıyı bildirmek, ekranın tamamına olan güveni
  /// zedeliyor.
  Future<bool> syncNowAndWait() async {
    final session = _ref.read(sessionControllerProvider).valueOrNull;
    if (session == null) return false;

    final bool basarili;
    try {
      basarili = await _ref
          .read(syncServiceProvider)
          .runOnce(session.companyId);
    } on Object {
      return false;
    }

    if (basarili) {
      _lastSyncedUserId = session.userId;
      _ref.read(lastSyncProvider.notifier).markSynced();
      _ref.invalidate(subscriptionStatusProvider);
    }
    return basarili;
  }

  void _trigger() {
    final session = _ref.read(sessionControllerProvider).valueOrNull;
    if (session == null) return;
    _lastSyncedUserId = session.userId;
    // Abonelik durumu da her senkron döngüsünde tazelenir — süre dolduğunda
    // (backend 402 dönmeye başladığında) dashboard'daki banner uygulama
    // yeniden başlatılmadan "sona erdi" kademesine geçebilsin.
    _ref.invalidate(subscriptionStatusProvider);
    unawaited(
      _ref.read(syncServiceProvider).runOnce(session.companyId).then((
        basarili,
      ) {
        // Yalnızca GERÇEKTEN sunucuya ulaşan tur "son senkron" sayılır.
        // Önceden `runOnce` hatayı yutup normal dönüyordu ve bu satır her
        // koşulda çalışıyordu; ekran, sunucuya hiç ulaşılamamışken bile
        // "az önce eşitlendi" yazıyordu.
        if (basarili) _ref.read(lastSyncProvider.notifier).markSynced();
      }),
    );
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _periodicTimer?.cancel();
    _outboxDebounce?.cancel();
  }
}

/// `ref.watch`/`ref.read` edildiği an bir kere başlar (Provider create
/// callback'i yalnızca ilk okumada çalışır) — bkz. `app.dart`.
final syncTriggerProvider = Provider<SyncTrigger>((ref) {
  final trigger = SyncTrigger(ref)..start();
  ref.onDispose(trigger.dispose);
  return trigger;
});
