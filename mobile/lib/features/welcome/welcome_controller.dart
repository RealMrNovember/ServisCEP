import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/providers/core_providers.dart';
import '../auth/data/session_controller.dart';

const _seenKey = 'welcome_seen_v1';

/// Karşılama (intro) akışı gösterildi mi? — yalnızca İLK açılışta, oturum
/// yokken gösterilir; kullanıcı akışı bitirince (veya atlayınca) kalıcı
/// olarak işaretlenir.
///
/// Var olan bir oturumla açılan uygulama karşılamayı hiç görmez ve bu durum
/// da "görüldü" sayılır — aksi halde güncellemeden önce kayıt olmuş bir
/// kullanıcı çıkış yaptığında tanıtım ekranına düşerdi (yanlış: tanıtım
/// yeni kullanıcı içindir, çıkış yapan kullanıcı ürünü zaten biliyor).
class WelcomeSeenController extends StateNotifier<AsyncValue<bool>> {
  WelcomeSeenController(this._storage, Ref ref)
    : super(const AsyncValue.loading()) {
    _load();
    ref.listen(sessionControllerProvider, (_, next) {
      if (next.valueOrNull != null && state.valueOrNull == false) {
        markSeen();
      }
    });
  }

  final FlutterSecureStorage _storage;

  Future<void> _load() async {
    final seen = await _storage.read(key: _seenKey);
    if (mounted) state = AsyncValue.data(seen == '1');
  }

  Future<void> markSeen() async {
    state = const AsyncValue.data(true);
    await _storage.write(key: _seenKey, value: '1');
  }
}

final welcomeSeenProvider =
    StateNotifierProvider<WelcomeSeenController, AsyncValue<bool>>((ref) {
      return WelcomeSeenController(ref.watch(secureStorageProvider), ref);
    });
