import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Uygulama içi güncelleme kontrolü — bkz. docs/06 § Mobil Uygulama
/// Otomatik Güncelleme (OTA).
///
/// Bu, yalnızca Play Store DIŞI (GitHub Releases sideload) kurulumlar
/// içindir. Play Store üzerinden kurulmuş bir uygulamada resmi Play In-App
/// Update API'si (bkz. play_update_service.dart) kullanılır — bu yüzden
/// [checkForUpdate], Play Store kurulumu tespit edilirse hemen `null` döner
/// ve iki güncelleme sistemi aynı anda kullanıcıya görünmez.
///
/// Backend `app/version` endpoint'i henüz yok (Phase 3 derinleşmedi), bu
/// yüzden GitHub Releases'in KENDİ herkese açık API'si doğrudan sorgulanır
/// (`/releases/latest`) — ek bir sunucuya ihtiyaç duymadan gerçek "yeni
/// sürüm var" tespiti sağlar. Backend hazır olduğunda bu, sunucu tabanlı
/// `app/version` sorgusuna geçebilir; arayüz (UpdateBanner) değişmez.
class UpdateInfo {
  const UpdateInfo({required this.version, required this.downloadUrl, required this.releaseNotes});
  final String version;
  final String downloadUrl;
  final String releaseNotes;
}

class UpdateChecker {
  static const _repo = 'RealMrNovember/ServisCEP';
  static const _apkAssetName = 'serviscep.apk';

  Future<UpdateInfo?> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (packageInfo.installerStore == 'com.android.vending') return null;
    final currentVersion = packageInfo.version;

    final response = await http
        .get(
          Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = (json['tag_name'] as String?) ?? '';
    final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;
    if (latestVersion.isEmpty) return null;

    if (!_isNewer(latestVersion, currentVersion)) return null;

    final assets = (json['assets'] as List?) ?? [];
    final apkAsset = assets.cast<Map<String, dynamic>>().firstWhere(
      (a) => a['name'] == _apkAssetName,
      orElse: () => const {},
    );
    final downloadUrl = apkAsset['browser_download_url'] as String?;
    if (downloadUrl == null) return null;

    return UpdateInfo(
      version: latestVersion,
      downloadUrl: downloadUrl,
      releaseNotes: (json['body'] as String?) ?? '',
    );
  }

  /// Basit semver karşılaştırması (x.y.z) — build-metadata (+N) yok sayılır.
  bool _isNewer(String latest, String current) {
    List<int> parse(String v) =>
        v.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final l = parse(latest);
    final c = parse(current);
    for (var i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv != cv) return lv > cv;
    }
    return false;
  }
}

final updateCheckerProvider = Provider<UpdateChecker>((ref) => UpdateChecker());

final updateInfoProvider = FutureProvider<UpdateInfo?>((ref) async {
  try {
    return await ref.watch(updateCheckerProvider).checkForUpdate();
  } catch (_) {
    return null; // sessiz basarisizlik - guncelleme kontrolu kritik degil
  }
});
