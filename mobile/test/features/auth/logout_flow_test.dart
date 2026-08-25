import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/features/auth/data/auth_repository.dart';

import '../../support/fake_sync_api_client.dart';
import '../../support/fake_token_store.dart';
import '../../support/in_memory_database.dart';

/// Çıkış akışının SIRASI.
///
/// Gerçek olay: admin panelindeki yeni günlük, her çıkışta iki tane 401
/// gösterdi — `DELETE /api/v1/devices` ve devam eden senkron istekleri.
/// Sebep, yerel jetonun sunucu tarafı temizlenmeden önce silinmesiydi.
/// Sonucu görünmez ama ciddiydi: çıkış yapılan cihaz sunucuda kayıtlı
/// kalıyor, o hesabın bildirimlerini almaya devam ediyor ve Sanctum
/// jetonu geçerliliğini koruyordu.
void main() {
  test('çıkışta sunucudaki oturum jetonu iptal edilir', () async {
    final db = createInMemoryDatabase();
    addTearDown(db.close);

    final api = FakeSyncApiClient();
    final tokenStore = FakeTokenStore(initialToken: 'gecerli-jeton');
    final repository = AuthRepository(
      db,
      const FlutterSecureStorage(),
      api,
      tokenStore,
    );

    await repository.logout();

    expect(api.logoutCalls, 1, reason: 'sunucuya çıkış bildirilmedi');
  });

  test('sunucu çıkışı yerel jeton silinmeden ÖNCE çağrılır', () async {
    final db = createInMemoryDatabase();
    addTearDown(db.close);

    final tokenStore = FakeTokenStore(initialToken: 'gecerli-jeton');
    final api = _TokenSpyClient(tokenStore);

    await AuthRepository(
      db,
      const FlutterSecureStorage(),
      api,
      tokenStore,
    ).logout();

    // Sıra ters olsaydı istek kimliksiz gider ve 401 alırdı.
    expect(
      api.tokenAtLogout,
      'gecerli-jeton',
      reason: 'çıkış isteği jeton silindikten sonra gönderilmiş',
    );
    expect(await tokenStore.read(), isNull, reason: 'yerel jeton kalmış');
  });
}

/// Çıkış isteği sırasında jetonun hâlâ duruyor olup olmadığını kaydeder.
class _TokenSpyClient extends FakeSyncApiClient {
  _TokenSpyClient(this._tokenStore);

  final FakeTokenStore _tokenStore;
  String? tokenAtLogout;

  @override
  Future<void> logout() async {
    tokenAtLogout = await _tokenStore.read();
  }
}
