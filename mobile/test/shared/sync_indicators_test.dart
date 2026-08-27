import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/shared/sync_indicators.dart';

void main() {
  group('Çevrimdışı şerit durumu', () {
    test('gönderilemeyen kayıt varken ASLA "tamamlandı" denmez', () {
      // Ekranda yaşandı: kuyruk boşalınca şerit gizleniyor, oradan da
      // "Tüm kayıtlar gönderildi" kutlamasına geçiyordu — bir kayıt
      // gönderilememişken. Kutlama yalnızca `hidden`dan doğduğu için,
      // bu durumun hidden'a düşmemesi kutlamayı da imkânsız kılıyor.
      expect(
        syncBannerStateFor(online: true, pending: 0, running: false, failed: 1),
        SyncBannerState.failed,
      );
    });

    test('gönderilemeyen, bekleyenin önüne geçer', () {
      // Bekleyen kayıt kendiliğinden gider; gönderilemeyen gitmez.
      // Kullanıcıya söylenmesi gereken, eylem isteyen olandır.
      expect(
        syncBannerStateFor(online: true, pending: 5, running: false, failed: 2),
        SyncBannerState.failed,
      );
    });

    test('çevrimdışıyken gönderilemeyen değil bağlantı bildirilir', () {
      // Çevrimdışıyken yeniden denemenin yolu yok; kullanıcıya
      // yapabileceği bir şey söylenmeli.
      expect(
        syncBannerStateFor(
          online: false,
          pending: 0,
          running: false,
          failed: 3,
        ),
        SyncBannerState.offline,
      );
    });

    test('gönderilemeyen yoksa davranış değişmez', () {
      expect(
        syncBannerStateFor(online: true, pending: 0, running: false, failed: 0),
        SyncBannerState.hidden,
      );
    });
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

    test('kapatılan şerit aynı durum sürerken kapalı kalır', () {
      expect(
        syncBannerStaysHidden(
          dismissedState: SyncBannerState.offline,
          dismissedPending: 3,
          currentState: SyncBannerState.offline,
          currentPending: 3,
        ),
        isTrue,
      );
    });

    test('kapatıldıktan sonra yeni kayıt birikirse geri gelir', () {
      // Kullanıcı kapatırken 3 kayıt vardı; şimdi 7 var. Kapatma kararı
      // o dördünü kapsamıyor.
      expect(
        syncBannerStaysHidden(
          dismissedState: SyncBannerState.offline,
          dismissedPending: 3,
          currentState: SyncBannerState.offline,
          currentPending: 7,
        ),
        isFalse,
      );
    });

    test('bağlantı durumu değişirse kapatma geçersizleşir', () {
      expect(
        syncBannerStaysHidden(
          dismissedState: SyncBannerState.offline,
          dismissedPending: 3,
          currentState: SyncBannerState.syncing,
          currentPending: 3,
        ),
        isFalse,
      );
    });

    test('bekleyen sayısı düşerse şerit geri gelmez', () {
      // İyi haber için kullanıcıyı rahatsız etmeye gerek yok.
      expect(
        syncBannerStaysHidden(
          dismissedState: SyncBannerState.waiting,
          dismissedPending: 9,
          currentState: SyncBannerState.waiting,
          currentPending: 2,
        ),
        isTrue,
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
