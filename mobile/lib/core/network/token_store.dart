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

  Future<String?> read() async {
    if (_loaded) return _cached;
    _cached = await _storage.read(key: _sessionTokenKey);
    _loaded = true;
    return _cached;
  }

  Future<void> write(String token) async {
    _cached = token;
    _loaded = true;
    await _storage.write(key: _sessionTokenKey, value: token);
  }

  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    await _storage.delete(key: _sessionTokenKey);
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return TokenStore(ref.watch(secureStorageProvider));
});
