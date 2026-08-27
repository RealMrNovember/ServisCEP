import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';

import '../database/app_database.dart';
import '../network/api_client.dart';
import '../network/sync_api_client.dart';
import '../network/token_store.dart';
import 'sync_service.dart';

/// Uygulama KAPALIYKEN/arka plandayken çalışan senkron.
///
/// NEDEN VAR: `SyncTrigger`'ın tetikleyicilerinin tamamı (bağlantı
/// dinleyicisi, `Timer.periodic`, `didChangeAppLifecycleState`) uygulamanın
/// Dart isolate'i canlıyken çalışır. Android/iOS uygulamayı arka plana
/// aldığında bu isolate askıya alınır: zamanlayıcı durur, bağlantı
/// dinleyicisi yayın yapmaz. Yani "çevrimdışı yaz, uygulamayı kapat,
/// internet gelince kendiliğinden gitsin" senaryosu HİÇ çalışmıyordu —
/// üstelik senkron ekranı kullanıcıya "uygulamayı açık tutmana gerek yok"
/// diye yazıyordu.
///
/// Bu iş yalnızca outbox'ı BOŞALTIR (push) — pull yapmaz. Arka planda
/// kullanıcıya gösterilecek bir ekran yok; önemli olan, kullanıcının
/// yazdığı kaydın sunucuya ulaşması.
///
/// DAYANIKLILIK: buradaki hiçbir hata dışarı sızmaz. Arka plan görevinden
/// fırlatılan bir hata, işletim sisteminin görevi tekrar tekrar
/// çalıştırmasına (ve pil tüketmesine) yol açar; bu yüzden her şey
/// yakalanır ve görev "başarılı" raporlanır.
const backgroundSyncTaskName = 'teknikcep-outbox-sync';
const _backgroundSyncUniqueName = 'teknikcep-outbox-sync-periodic';

/// Android'de periyodik görevler için işletim sistemi alt sınırı 15 dakika.
const _backgroundSyncInterval = Duration(minutes: 15);

/// Arka plan isolate'inin giriş noktası.
///
/// `vm:entry-point`: sürüm derlemesinde ağaç sarsma (tree shaking) bu
/// fonksiyonu atmasın diye zorunlu — aksi halde görev yalnızca hata ayıklama
/// derlemesinde çalışır ve sorun ancak yayından sonra fark edilir.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await _outboxGonder();
    } on Object catch (e) {
      // Bilinçli olarak yutulur — bkz. sınıf açıklaması.
      debugPrint('Arka plan senkronu başarısız: $e');
    }
    return true;
  });
}

Future<void> _outboxGonder() async {
  // Arka plan isolate'inde platform kanalları (secure storage, path_provider)
  // ancak binding kurulduktan sonra çalışır.
  WidgetsFlutterBinding.ensureInitialized();

  final tokenStore = TokenStore(
    const FlutterSecureStorage(aOptions: AndroidOptions(resetOnError: true)),
  );
  // Oturum yoksa yapacak iş de yok; veritabanını hiç açmaya gerek kalmaz.
  if (await tokenStore.read() == null) return;

  final db = AppDatabase();
  try {
    // `companyId` bilerek yerelden okunuyor: oturumu sunucudan geri yüklemek
    // (auth/me) arka planda gereksiz bir ağ turu ve ek hata yüzeyi olurdu.
    final company = await (db.select(
      db.companies,
    )..limit(1)).getSingleOrNull();
    if (company == null) return;

    final api = DioSyncApiClient(ApiClient(tokenStore));
    final sync = SyncService(db, api, tokenStore);
    await sync.drainOutboxOnly();
  } finally {
    await db.close();
  }
}

/// Periyodik arka plan senkronunu kaydeder. Uygulama açılışında çağrılır;
/// aynı `uniqueName` ile tekrar kaydetmek mevcut görevi değiştirir
/// (`ExistingPeriodicWorkPolicy.keep` ile ikinci bir kopya oluşmaz).
///
/// Hata durumunda sessizce vazgeçilir: arka plan senkronu bir iyileştirmedir,
/// uygulamanın açılışını engellememelidir.
Future<void> registerBackgroundSync() async {
  try {
    await Workmanager().initialize(backgroundSyncDispatcher);
    await Workmanager().registerPeriodicTask(
      _backgroundSyncUniqueName,
      backgroundSyncTaskName,
      frequency: _backgroundSyncInterval,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      // Ağ yokken uyandırmanın anlamı yok; pil tüketir.
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
    );
  } on Object catch (e) {
    debugPrint('Arka plan senkronu kaydedilemedi: $e');
  }
}
