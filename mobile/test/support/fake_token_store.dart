import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:serviscep/core/network/token_store.dart';

/// Gerçek `flutter_secure_storage` platform kanalına hiç dokunmaz —
/// `super`'ın alanları özel olduğu için constructor'a zararsız bir
/// `FlutterSecureStorage()` verilir, ama `read`/`write`/`clear`
/// tamamen bellek içinde ezilir.
class FakeTokenStore extends TokenStore {
  FakeTokenStore({String? initialToken})
    : _token = initialToken,
      super(const FlutterSecureStorage());

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
