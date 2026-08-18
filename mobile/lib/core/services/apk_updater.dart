import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'update_checker.dart';

/// APK'yı uygulama içinden indirip Android yükleyicisine açar — bkz.
/// docs/06 § Mobil Uygulama Otomatik Güncelleme (OTA).
///
/// Önceden [UpdateBanner] tarayıcıya yönlendirip GitHub sayfasından elle
/// indirme yaptırıyordu; kullanıcı bunu "saçmalık" olarak işaretledi —
/// güncelleme artık tamamen uygulama içinde indirilir ve kurulum ekranı
/// doğrudan açılır. "Bilinmeyen kaynaklardan yükleme" izni sistem
/// tarafından yönetilir; bu, uygulama kodunun atlayamayacağı tek adımdır.
class ApkUpdater {
  const ApkUpdater();

  Future<void> downloadAndInstall(
    UpdateInfo info, {
    required void Function(double progress) onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final filePath = p.join(dir.path, 'serviscep-update.apk');

    await Dio().download(
      info.downloadUrl,
      filePath,
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        onProgress(received / total);
      },
    );

    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      throw ApkInstallException(result.type, result.message);
    }
  }
}

class ApkInstallException implements Exception {
  ApkInstallException(this.type, this.message);
  final ResultType type;
  final String message;

  bool get isPermissionDenied => type == ResultType.permissionDenied;
}

const apkUpdater = ApkUpdater();
