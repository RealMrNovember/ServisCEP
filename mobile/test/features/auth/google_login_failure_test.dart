import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/core/network/api_client.dart';
import 'package:serviscep/core/network/sync_api_client.dart';
import 'package:serviscep/features/auth/data/auth_repository.dart';

import '../../support/fake_sync_api_client.dart';
import '../../support/fake_token_store.dart';
import '../../support/in_memory_database.dart';

/// Google ile girişte hata AYRIMI.
///
/// Gerçek olay: mevcut (üstelik ücretli) bir hesabın sahibi uygulamayı
/// silip yeniden kurdu, Google ile giriş yaptı ve sunucuya ulaşılamadığı
/// için "hesabı oluştur" ekranına düştü. Giriş ekranı her `AuthException`'ı
/// "böyle bir hesap yok" sayıyordu.
///
/// Bu testler o ayrımı sabitler: ağ hatası kayıt akışını TETİKLEMEZ,
/// yalnızca sunucunun açıkça "eşleşen hesap yok" demesi tetikler.
class _AuthFake extends FakeSyncApiClient {
  _AuthFake(this.error);

  final ApiException error;
  var googleLoginCalls = 0;

  @override
  Future<AuthTokenResult> loginWithGoogle(String idToken) async {
    googleLoginCalls++;
    throw error;
  }
}

AuthRepository _repository(ApiException error) {
  final db = createInMemoryDatabase();
  addTearDown(db.close);
  // Güvenli depoya bu akışta hiç dokunulmuyor: hata, oturum yazılmadan
  // çok önce fırlıyor. Bu yüzden platform kanalı gerektiren gerçek nesne
  // güvenle verilebilir.
  return AuthRepository(
    db,
    const FlutterSecureStorage(),
    _AuthFake(error),
    FakeTokenStore(),
  );
}

void main() {
  test('ağ hatası kayıt akışını tetiklemez', () async {
    final repository = _repository(
      ApiException(null, 'Ağ hatası: Connection timed out'),
    );

    await expectLater(
      repository.loginWithGoogle('token', email: 'a@b.com'),
      throwsA(
        isA<AuthException>()
            .having((e) => e.isNetworkFailure, 'isNetworkFailure', isTrue)
            .having((e) => e.accountMissing, 'accountMissing', isFalse),
      ),
    );
  });

  test('ağ hatasının asıl sebebi mesajda kalır', () async {
    final repository = _repository(
      ApiException(null, 'Ağ hatası: Connection timed out'),
    );

    try {
      await repository.loginWithGoogle('token', email: 'a@b.com');
      fail('hata bekleniyordu');
    } on AuthException catch (e) {
      expect(e.message, contains('Sunucuya ulaşılamadı'));
      expect(e.message, contains('Connection timed out'));
    }
  });

  test('sunucu "eşleşen hesap yok" derse kayıt akışı tetiklenir', () async {
    final repository = _repository(
      ApiException(
        422,
        'Bu Google hesabıyla eşleşen bir hesap yok. Önce kayıt olmalısın.',
      ),
    );

    await expectLater(
      repository.loginWithGoogle('token', email: 'a@b.com'),
      throwsA(
        isA<AuthException>()
            .having((e) => e.accountMissing, 'accountMissing', isTrue)
            .having((e) => e.isNetworkFailure, 'isNetworkFailure', isFalse),
      ),
    );
  });

  test('başka bir sunucu hatası kayıt akışını tetiklemez', () async {
    // Ör. abonelik/sunucu hatası — kullanıcı yeni hesap açmaya
    // yönlendirilmemeli.
    final repository = _repository(ApiException(500, 'Sunucu hatası'));

    await expectLater(
      repository.loginWithGoogle('token', email: 'a@b.com'),
      throwsA(
        isA<AuthException>()
            .having((e) => e.accountMissing, 'accountMissing', isFalse)
            .having((e) => e.isNetworkFailure, 'isNetworkFailure', isFalse),
      ),
    );
  });
}
