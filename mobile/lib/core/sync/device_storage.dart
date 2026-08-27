import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Uygulamanın bu cihazda kapladığı yer.
///
/// Eşitleme ekranında gösteriliyor: "verilerim nerede, ne kadar yer
/// kaplıyor" sorusu çevrimdışı çalışan bir uygulamada kullanıcının en sık
/// sorduğu şeylerden biri ve cevabı hiçbir yerde yazmıyordu.
class DeviceStorage {
  const DeviceStorage({required this.databaseBytes, required this.mediaBytes});

  final int databaseBytes;
  final int mediaBytes;
}

/// Yerel veritabanı ve medya dizininin boyutu.
///
/// Dizin gezintisi diskten okuma yapıyor; her karede değil yalnızca ekran
/// açıldığında hesaplanıyor (FutureProvider, otomatik yeniden okuma yok).
final deviceStorageProvider = FutureProvider<DeviceStorage>((ref) async {
  // drift_flutter, `driftDatabase(name: 'serviscep')` için veritabanını
  // BELGELER dizinine `serviscep.sqlite` adıyla açıyor
  // (drift_flutter/lib/src/native.dart: getApplicationDocumentsDirectory).
  //
  // Burada önce destek dizinine bakılıyordu; dosya bulunamadığı için
  // ekranda "Yerel veritabanı 0 B" yazıyordu. Var olmayan bir dosyanın
  // boyutunu sıfır diye göstermek, ölçümü yanlış yapmaktan daha kötü:
  // kullanıcıya verisinin hiç yer kaplamadığını söylüyor.
  final belgeler = await getApplicationDocumentsDirectory();

  // WAL kipinde asıl veri `-wal` dosyasında bekliyor olabilir; yalnızca
  // ana dosyaya bakmak boyutu olduğundan küçük gösterir.
  var dbBoyut = 0;
  for (final ek in const ['', '-wal', '-shm']) {
    final dosya = File(p.join(belgeler.path, 'serviscep.sqlite$ek'));
    if (await dosya.exists()) dbBoyut += await dosya.length();
  }

  final medya = Directory(p.join(belgeler.path, 'serviscep_media'));
  var medyaBoyut = 0;
  if (await medya.exists()) {
    await for (final girdi in medya.list(recursive: true)) {
      if (girdi is File) medyaBoyut += await girdi.length();
    }
  }

  return DeviceStorage(databaseBytes: dbBoyut, mediaBytes: medyaBoyut);
});

/// "4,2 MB" — bin değil 1024 tabanı, Android'in dosya yöneticisiyle aynı
/// rakamı göstersin diye.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
  return '${(mb / 1024).toStringAsFixed(1).replaceAll('.', ',')} GB';
}
