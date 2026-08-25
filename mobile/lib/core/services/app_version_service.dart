import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../network/api_client.dart';

/// Sunucunun bildirdiği yayın sürümü.
class AppVersionInfo {
  const AppVersionInfo({
    required this.latestBuild,
    required this.minBuild,
    required this.currentBuild,
    this.latestVersion,
    this.notes,
    this.storeUrl,
  });

  final int latestBuild;

  /// Bu kodun altındaki kurulumlarda güncelleme ertelenemez.
  final int minBuild;

  final int currentBuild;
  final String? latestVersion;
  final String? notes;
  final String? storeUrl;

  bool get hasUpdate => latestBuild > currentBuild;

  /// Sunucu sözleşmesi kırıldığında eski istemciyi dışarıda bırakmanın
  /// tek yolu; normalde `minBuild` 0 olur ve bu hiç tetiklenmez.
  bool get isMandatory => currentBuild < minBuild;
}

/// Güncelleme kontrolü — Play'e değil KENDİ sunucumuza sorar.
///
/// Play'in In-App Update API'si cihazdaki Google Play Services'e soruyor ve
/// sürüm o cihaza yayılana kadar "güncelleme yok" diyor. Bu yayılma saatler
/// sürebiliyor: yeni sürüm yayınlanmış olsa bile kullanıcı haberdar
/// olmuyordu ve biz de neden olmadığını göremiyorduk.
///
/// Sunucudan sormak "yayında" anını bizim kontrolümüze alır ve sürüm notunu
/// da kendi yazdığımız metinden gösterir (bkz. admin panel → Uygulama
/// sürümü).
///
/// Kurulumun kendisi yine Play üzerinden yapılır — Android'de bir uygulama
/// kendini güncelleyemez. Bu servis yalnızca "yeni sürüm var mı" sorusunu
/// cevaplar.
class AppVersionService {
  AppVersionService(this._client);

  final ApiClient _client;

  /// Sunucuya ulaşılamazsa null döner: güncelleme kontrolü, uygulamanın
  /// açılışını engelleyebilecek bir iş değil.
  Future<AppVersionInfo?> check() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/app/version',
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) return null;

      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      return AppVersionInfo(
        latestBuild: (data['latest_build'] as num?)?.toInt() ?? 0,
        minBuild: (data['min_build'] as num?)?.toInt() ?? 0,
        currentBuild: currentBuild,
        latestVersion: data['latest_version'] as String?,
        notes: data['notes'] as String?,
        storeUrl: data['store_url'] as String?,
      );
    } on Object {
      return null;
    }
  }
}

final appVersionServiceProvider = Provider<AppVersionService>((ref) {
  return AppVersionService(ref.watch(apiClientProvider));
});
