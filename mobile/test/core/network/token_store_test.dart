import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/core/network/token_store.dart';

/// Güvenli depo bozulduğunda ne olacağı.
///
/// Gerçek olay: bir cihazda `flutter_secure_storage` çözülemez hâle geldi
/// (uygulama silinip kurulunca Android Auto Backup şifreli veriyi geri
/// yükledi ama Keystore anahtarını yüklemedi). `TokenStore.read()` hata
/// fırlatıyordu ve bu metot Dio'nun `onRequest` interceptor'ından
/// çağrıldığı için Dio hatayı YANITSIZ bir ağ hatasına çeviriyordu.
/// Kullanıcı, interneti çalışırken "internet bağlantısı gerekli" görüyor,
/// istek hiç atılmadığı için sunucu loglarında da iz bulunmuyordu.
///
/// Bu testler o davranışı sabitler: depo patlasa bile okuma null döner,
/// yazma ve temizleme sessizce geçer.
class _ExplodingStorage extends FlutterSecureStorage {
  const _ExplodingStorage();

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('BadPaddingException: veri çözülemiyor');
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('yazılamıyor');
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('silinemiyor');
  }
}

void main() {
  test('depo okuma patlarsa null döner, hata fırlatmaz', () async {
    final store = TokenStore(const _ExplodingStorage());

    await expectLater(store.read(), completion(isNull));
  });

  test('depo yazma patlarsa hata fırlatmaz ve bellekte tutulur', () async {
    final store = TokenStore(const _ExplodingStorage());

    await expectLater(store.write('abc'), completes);
    // Kalıcı yazma başarısız olsa da oturum uygulama açıkken sürmeli.
    expect(await store.read(), 'abc');
  });

  test('depo silme patlarsa hata fırlatmaz ve bellek temizlenir', () async {
    final store = TokenStore(const _ExplodingStorage());
    await store.write('abc');

    await expectLater(store.clear(), completes);
    expect(await store.read(), isNull);
  });
}
