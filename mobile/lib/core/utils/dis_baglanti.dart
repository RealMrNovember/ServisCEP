import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Uygulamanın dışına çıkan bağlantıların TEK kapısı.
///
/// Neden var: bu çağrılar uygulama genelinde `await launchUrl(...)` diye
/// yazılıyordu ve dönüş değeri hiç okunmuyordu. Android 11'den itibaren
/// paket görünürlüğü yüzünden `url_launcher` hedefi çözemediğinde `false`
/// dönüyor — istisna fırlatmıyor. Sonuç: kullanıcı düğmeye basıyor,
/// HİÇBİR ŞEY olmuyor, ekranda tek bir işaret bile çıkmıyor. Gizlilik
/// politikası, telefon araması ve WhatsApp destek düğmesi sahada aylarca
/// böyle ölü kaldı ve kimse bunun bir hata olduğunu anlayamadı.
///
/// Görünürlük tarafı [AndroidManifest.xml]'deki `<queries>` bloğuyla
/// çözüldü; burası ikinci savunma hattı: hedef yine de açılamazsa
/// (tarayıcısı kaldırılmış cihaz, WhatsApp kurulu değil, kısıtlı iş
/// profili) kullanıcı bunu ÖĞRENİR ve adres panoya kopyalandığı için
/// elinde bir çıkış yolu kalır.
abstract final class DisBaglanti {
  static Future<bool> _urlLauncherIle(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  /// Bağlantıyı harici uygulamada açar.
  ///
  /// Dönüş: açıldıysa true. Açılamadıysa çağıran tarafın ek bir şey
  /// yapması gerekmez — kullanıcı zaten bilgilendirilmiştir.
  ///
  /// [mesajGoster] geri çağrısı UI katmanından verilir; bu dosya
  /// bilerek `BuildContext` almıyor, böylece widget ağacından bağımsız
  /// yerlerden de çağrılabiliyor.
  static Future<bool> ac(
    Uri uri, {
    required void Function(String mesaj) mesajGoster,
    String? hataMesaji,
    @visibleForTesting Future<bool> Function(Uri uri)? baslatici,
  }) async {
    var acildi = false;
    try {
      acildi = await (baslatici ?? _urlLauncherIle)(uri);
    } on Object {
      // Her şey yakalanıyor — tür ayıklamak burada işe yaramaz. Bu
      // fonksiyonun tek görevi "sessiz kalma"; hangi istisnanın geldiği
      // (PlatformException, MissingPluginException, eklentinin ileride
      // ekleyeceği bir tür) sonucu değiştirmiyor: kullanıcı yine
      // bilgilendirilmeli.
      acildi = false;
    }

    if (acildi) return true;

    // Panoya kopyalama, kullanıcıyı çıkmazda bırakmamak için: adresi
    // başka bir cihazda ya da tarayıcıya elle yapıştırarak açabilir.
    var panoyaYazildi = true;
    try {
      await Clipboard.setData(ClipboardData(text: uri.toString()));
    } on PlatformException {
      panoyaYazildi = false;
    }

    mesajGoster(
      hataMesaji ??
          (panoyaYazildi
              ? 'Bağlantı açılamadı. Adres panoya kopyalandı.'
              : 'Bağlantı açılamadı: $uri'),
    );
    return false;
  }
}

/// Widget'lardan kullanım kolaylığı.
///
/// Messenger `await`'ten ÖNCE yakalanıyor: bağlantı denemesi sürerken
/// ekran kapanırsa elde ölü bir `BuildContext` kalmaz.
extension DisBaglantiContext on BuildContext {
  Future<bool> disBaglantiAc(
    Uri uri, {
    String? hataMesaji,
    @visibleForTesting Future<bool> Function(Uri uri)? baslatici,
  }) {
    final messenger = ScaffoldMessenger.of(this);
    return DisBaglanti.ac(
      uri,
      hataMesaji: hataMesaji,
      baslatici: baslatici,
      mesajGoster: (mesaj) =>
          messenger.showSnackBar(SnackBar(content: Text(mesaj))),
    );
  }
}
