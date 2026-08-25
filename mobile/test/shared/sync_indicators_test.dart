import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/shared/sync_indicators.dart';

void main() {
  group('Çevrimdışı şerit durumu', () {
    test('bağlantı yoksa çevrimdışı der, kuyruk boş olsa bile', () {
      expect(
        syncBannerStateFor(online: false, pending: 0, running: false),
        SyncBannerState.offline,
      );
    });

    test('bağlantı yokken tur çalışıyor görünse de çevrimdışı kazanır', () {
      // Bağlantı gitmişken devam eden bir tur, kullanıcıya "eşitleniyor"
      // diye gösterilmemeli; sonucu zaten başarısız olacak.
      expect(
        syncBannerStateFor(online: false, pending: 4, running: true),
        SyncBannerState.offline,
      );
    });

    test('gerçekten tur çalışıyorsa eşitleniyor der', () {
      expect(
        syncBannerStateFor(online: true, pending: 3, running: true),
        SyncBannerState.syncing,
      );
    });

    test('kuyruk dolu ama tur çalışmıyorsa EŞİTLENİYOR DEMEZ', () {
      // Bu testin varlık sebebi somut: bir sürümde uygulama saatlerce
      // sunucuya ulaşamadığı hâlde arayüz eşitlenmiş gibi davrandı.
      // Kuyrukta kayıt olması, gönderiliyor olması demek değildir.
      final durum = syncBannerStateFor(
        online: true,
        pending: 5,
        running: false,
      );

      expect(durum, SyncBannerState.waiting);
      expect(durum, isNot(SyncBannerState.syncing));
    });

    test('bağlantı var, kuyruk boş, tur yok: şerit gizlenir', () {
      // Sessizlik iyi haberdir — her şey yolundayken şerit yer kaplamaz.
      expect(
        syncBannerStateFor(online: true, pending: 0, running: false),
        SyncBannerState.hidden,
      );
    });

    test('done durumu hesaplamadan çıkmaz, yalnızca geçişle üretilir', () {
      // done, "kuyruk yeni boşaldı" geçişinin sonucudur; anlık üç
      // sinyalden türetilemez. Hesaplama fonksiyonu onu asla döndürmemeli.
      for (final online in [true, false]) {
        for (final pending in [0, 1, 9]) {
          for (final running in [true, false]) {
            expect(
              syncBannerStateFor(
                online: online,
                pending: pending,
                running: running,
              ),
              isNot(SyncBannerState.done),
            );
          }
        }
      }
    });
  });
}
