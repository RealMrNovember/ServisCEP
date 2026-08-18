import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Google Play üzerinden kurulmuş uygulamalar için resmi Play In-App Update
/// API entegrasyonu — bkz. docs/06 § Mobil Uygulama Otomatik Güncelleme
/// (OTA).
///
/// Play, güncellemeyi tamamen arka planda indirir; kullanıcı hiçbir indirme
/// ekranı görmez, yalnızca indirme bittiğinde "yeniden başlat" seçeneği
/// sunulur (bkz. [PlayUpdateReadyNotifier]). Play Store dışı (GitHub
/// Releases sideload) kurulumlarda bu API kullanılamaz — böyle durumlarda
/// sessizce hiçbir şey yapmaz ve GitHub tabanlı [UpdateChecker]/[UpdateBanner]
/// devreye girer (bkz. update_checker.dart, update_banner.dart).
class PlayUpdateService {
  const PlayUpdateService();

  Future<bool> isPlayStoreInstall() async {
    final info = await PackageInfo.fromPlatform();
    return info.installerStore == 'com.android.vending';
  }

  Future<void> checkAndStartFlexibleUpdate({required VoidCallback onReadyToInstall}) async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      if (!info.flexibleUpdateAllowed) return;

      final result = await InAppUpdate.startFlexibleUpdate();
      if (result != AppUpdateResult.success) return;

      InAppUpdate.installUpdateListener.listen((status) {
        if (status == InstallStatus.downloaded) onReadyToInstall();
      });
    } catch (_) {
      // Play Store kurulumu değil ya da Play Core kullanılamıyor — sessizce
      // yok say, bu kritik bir hata değildir.
    }
  }

  Future<void> completeUpdate() => InAppUpdate.completeFlexibleUpdate();
}

const playUpdateService = PlayUpdateService();

class PlayUpdateReadyNotifier extends StateNotifier<bool> {
  PlayUpdateReadyNotifier() : super(false) {
    playUpdateService.checkAndStartFlexibleUpdate(onReadyToInstall: () => state = true);
  }
}

/// true olduğunda Play güncellemesi indirilmiş ve kurulum için hazırdır.
final playUpdateReadyProvider = StateNotifierProvider<PlayUpdateReadyNotifier, bool>((ref) {
  return PlayUpdateReadyNotifier();
});
