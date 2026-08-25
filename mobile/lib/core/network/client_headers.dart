import 'dart:io' show Platform;

import 'package:package_info_plus/package_info_plus.dart';

/// Her isteğe eklenen istemci künyesi.
///
/// Sunucu bu başlıkları kayıt altına alıyor; amacı bir kullanıcı sorun
/// bildirdiğinde "hangi sürümü kullanıyorsunuz" sorusunu sormadan
/// cevaplayabilmek. Başlıklar gönderilmediği sürece sunucudaki sürüm
/// sütunları boş kalıyordu ve destek tarafı kör çalışıyordu.
///
/// Kimlik doğrulaması GEREKTİRMEZ ve kişisel veri TAŞIMAZ: yalnızca
/// uygulama sürümü, yapı numarası ve işletim sistemi bilgisi gider.
abstract final class ClientHeaders {
  static const appVersion = 'X-App-Version';
  static const appBuild = 'X-App-Build';
  static const platform = 'X-Platform';
  static const device = 'X-Device-Model';

  static Map<String, String>? _cache;

  /// Başlıkları üretir ve önbelleğe alır.
  ///
  /// [PackageInfo] platform kanalı üzerinden okunuyor; her istekte yeniden
  /// sormak gereksiz. Okuma başarısız olursa boş harita döner — künye
  /// bilgisi uğruna istek engellenmez.
  static Future<Map<String, String>> read() async {
    final cached = _cache;
    if (cached != null) return cached;

    try {
      final info = await PackageInfo.fromPlatform();
      final basliklar = <String, String>{
        appVersion: info.version,
        appBuild: info.buildNumber,
        platform: Platform.operatingSystem,
        // Model adı için ayrı bir paket gerekiyor; işletim sistemi sürümü
        // destek için yeterli ayrım sağlıyor ve ek bağımlılık istemiyor.
        device: Platform.operatingSystemVersion,
      };
      _cache = basliklar;
      return basliklar;
    } on Object {
      return const {};
    }
  }

  /// Yalnızca testler için — önbelleği sıfırlar.
  static void resetForTest() => _cache = null;
}
