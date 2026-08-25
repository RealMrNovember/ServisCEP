import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Uygulamanın kendi belge dizinindeki medya deposu.
///
/// `image_picker` ve kamera geçici dizine yazar; işletim sistemi orayı
/// haber vermeden temizleyebilir. Belgede kullanılacak her görsel bu yüzden
/// önce buraya kopyalanır — teklif PDF'i, logonun seçildiği andan aylar
/// sonra da üretilebilmeli.
abstract final class MediaStorage {
  static const _root = 'serviscep_media';

  static Future<Directory> _dir(String bucket) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _root, bucket));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Kırpılmış logoyu (PNG) kalıcı dizine yazar ve yolunu döndürür.
  ///
  /// Dosya adına bir sürüm damgası eklenir: Flutter'ın görsel önbelleği
  /// dosya yoluna göre anahtarlanır, aynı yola yazılan yeni logo ekranda
  /// eskisi olarak görünürdü.
  static Future<String> writeLogo({
    required String bucket,
    required String ownerId,
    required Uint8List bytes,
    required int stamp,
  }) async {
    final dir = await _dir(bucket);

    // Aynı sahibin eski logoları birikmesin.
    await for (final entry in dir.list()) {
      if (entry is File && p.basename(entry.path).startsWith('$ownerId-')) {
        await entry.delete();
      }
    }

    final file = File(p.join(dir.path, '$ownerId-$stamp.png'));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static Future<void> deleteIfExists(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
