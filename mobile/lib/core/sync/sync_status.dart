import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../providers/core_providers.dart';

const _lastSyncKey = 'last_sync_at';

/// Son BAŞARILI senkronun zamanı.
///
/// Kalıcı saklanır: kullanıcı uygulamayı kapatıp açtığında "en son ne
/// zaman eşitlendim?" bilgisi sıfırlanmamalı — bu bilgi, verisinin
/// sunucuya ulaşıp ulaşmadığını anlamasının tek yolu.
class LastSyncController extends StateNotifier<AsyncValue<DateTime?>> {
  LastSyncController(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final raw = await _ref.read(secureStorageProvider).read(key: _lastSyncKey);
    if (!mounted) return;
    state = AsyncValue.data(raw == null ? null : DateTime.tryParse(raw));
  }

  Future<void> markSynced() async {
    final now = DateTime.now();
    state = AsyncValue.data(now);
    await _ref
        .read(secureStorageProvider)
        .write(key: _lastSyncKey, value: now.toIso8601String());
  }
}

final lastSyncProvider =
    StateNotifierProvider<LastSyncController, AsyncValue<DateTime?>>((ref) {
      return LastSyncController(ref);
    });

/// Sunucuya gönderilmeyi bekleyen yazma sayısı — 0 ise her şey eşitlenmiş
/// demektir.
final pendingSyncCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.selectOnly(db.syncOperations)
    ..addColumns([db.syncOperations.id])
    ..where(db.syncOperations.status.equals('PENDING'));
  return query.watch().map((rows) => rows.length);
});

/// Gönderilemeyen (kalıcı hata almış) yazma sayısı.
final failedSyncCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.selectOnly(db.syncOperations)
    ..addColumns([db.syncOperations.id])
    ..where(db.syncOperations.status.equals('FAILED'));
  return query.watch().map((rows) => rows.length);
});

/// Gönderilemeyen yazmaların kendisi.
///
/// Sayıyı göstermek yetmiyor: "1 kayıt gönderilemedi" diyen bir ekran,
/// kullanıcının "hangisi ve neden?" sorusunu cevapsız bırakıyor ve elinde
/// yeniden denemekten başka bir şey kalmıyor. `lastError` zaten
/// yazılıyordu, hiçbir yerde okunmuyordu.
final failedSyncOperationsProvider = StreamProvider<List<SyncOperation>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.syncOperations)
        ..where((o) => o.status.equals('FAILED'))
        ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
      .watch();
});

/// Cihazın şu anki bağlantı durumu.
///
/// `onConnectivityChanged` yalnızca DEĞİŞİM anında yayın yapar. Tek başına
/// dinlemek, bağlantı durumu hiç değişmediğinde akışın hiç veri
/// üretmemesi demekti; ekranda "Kontrol ediliyor…" sonsuza kadar asılı
/// kalıyordu. Bu yüzden önce mevcut durum okunup yayınlanır.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  bool cevrimici(List<ConnectivityResult> results) =>
      !results.contains(ConnectivityResult.none);

  try {
    yield cevrimici(await connectivity.checkConnectivity());
  } on Object {
    // Platform kanalı cevap vermezse akış yine de dinlemeye devam eder.
  }

  yield* connectivity.onConnectivityChanged.map(cevrimici);
});

/// Son senkronun "taze" sayıldığı süre.
///
/// Bu eşiğin üstündeyse ekranda "eşitlendi" DENMEZ. Sebebi somut: cihazın
/// internetinin olması sunucuya ulaşabildiği anlamına gelmiyor — bir
/// sürümde uygulama saatlerce sunucuya hiç bağlanamadı ama ekran "her şey
/// eşitlendi" yazmaya devam etti. Kuyruğun boş olması eşitlenmiş olmak
/// değildir; yalnızca gönderilecek bir şey olmadığını gösterir.
const syncFreshnessWindow = Duration(minutes: 30);
