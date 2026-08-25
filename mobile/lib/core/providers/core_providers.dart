import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  // `resetOnError`: Android Keystore ile şifrelenmiş bir değer
  // ÇÖZÜLEMEZ hâle gelebiliyor — en yaygın sebebi, uygulama silinip
  // kurulduğunda Android Auto Backup'ın şifreli veriyi geri yüklemesi ama
  // anahtarın geri gelmemesi. Bu durumda paket varsayılan olarak hata
  // fırlatıyor ve okuma sonsuza kadar patlıyor; kayıt/giriş isteği hiç
  // atılamadığı için kullanıcı "internet bağlantısı gerekli" görüyordu.
  //
  // Bu seçenekle bozuk kayıt silinip null dönülür: kullanıcı en kötü
  // ihtimalle yeniden giriş yapar, uygulama kilitlenmez.
  //
  // NOT: `encryptedSharedPreferences` bilinçli olarak DEĞİŞTİRİLMEDİ —
  // değiştirmek depolama arka ucunu değiştirir ve mevcut tüm kullanıcıların
  // oturumunu düşürürdü.
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );
});
