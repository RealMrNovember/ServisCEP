import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../providers/core_providers.dart';

const _sessionTokenKey = 'session_token';

/// Backend Sanctum token'ını saklar — `ApiClient`'ın interceptor'ı ile
/// `AuthRepository` arasında paylaşılan tek kaynak. Bellekte önbelleklenir
/// ki her istekte `flutter_secure_storage`'a (platform kanalı) gidilmesin.
class TokenStore {
  TokenStore(this._storage);

  final FlutterSecureStorage _storage;
  String? _cached;
  bool _loaded = false;

  /// Token okunamazsa HATA FIRLATMAZ, null döner.
  ///
  /// Bu metot Dio'nun `onRequest` interceptor'ından çağrılıyor; oradan
  /// fırlayan her hata Dio tarafından "yanıtsız istek" hatasına çevriliyor
  /// ve uygulamada ağ sorunundan ayırt edilemiyordu. Gerçek olay: bir
  /// cihazda güvenli depo çözülemez hâle geldi ve kullanıcı, interneti
  /// çalışırken günlerce "internet bağlantısı gerekli" hatası aldı; istek
  /// hiç atılmadığı için sunucu loglarında da hiçbir iz yoktu.
  ///
  /// Token okunamaması, isteğin atılmasına engel değildir: sunucu 401
  /// döner, kullanıcı yeniden giriş yapar. Bu, sessiz bir kilitlenmeden
  /// çok daha iyi bir sonuç.
  Future<String?> read() async {
    if (_loaded) return _cached;
    try {
      _cached = await _storage.read(key: _sessionTokenKey);
    } on Object {
      _cached = null;
    }
    _loaded = true;
    return _cached;
  }

  Future<void> write(String token) async {
    _cached = token;
    _loaded = true;
    try {
      await _storage.write(key: _sessionTokenKey, value: token);
    } on Object {
      // Bellekteki kopya yazıldı; kalıcı yazma başarısızsa oturum yalnızca
      // uygulama kapanana kadar sürer — girişi tamamen engellemekten iyi.
    }
  }

  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    try {
      await _storage.delete(key: _sessionTokenKey);
    } on Object {
      // Silinemedi; bellekteki kopya zaten temizlendi.
    }
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return TokenStore(ref.watch(secureStorageProvider));
});
