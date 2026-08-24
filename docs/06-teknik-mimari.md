# 06 — Teknik Mimari (Mobil UX ve Teknoloji Yığını)

> Kaynak: orijinal spesifikasyon §42–§44, §46–§47, §61–§62, §68, §86–§87.

## 1. Mobil Navigasyon

Ana navigasyon sade tutulmalıdır:

```
┌────────────────────────────┐
│                            │
│       EKRAN İÇERİĞİ        │
│                            │
└────────────────────────────┘

 Ana Sayfa | İşler | Müşteriler | Belgeler | Daha Fazla
```

"Yeni İş" gibi kritik aksiyonlar, navigasyon derinliğinden bağımsız olarak **her zaman hızlı erişilebilir** olmalıdır (ör. sabit bir aksiyon butonu).

## 2. Mobil Tasarım Prensipleri

> **Zorunlu gereksinim:** Mobil arayüz **tamamen modern ve şık** olmalıdır — "işlevsel ama sade" ilkesi, düşük kaliteli/eski görünümlü bir arayüz için mazeret değildir. Referans kalite seviyesi: piyasadaki premium SaaS mobil uygulamaları (Linear, Notion, Stripe Dashboard gibi ürünlerin mobil deneyimi) — tutarlı bir tasarım sistemi (renk paleti, tipografi, spacing, bileşen kütüphanesi), akıcı geçiş/animasyonlar ve özenli boş/yükleme/hata durumları içermelidir. Marka renk paleti için bkz. [14 — Marka Kimliği](14-marka-kimligi.md).

Saha koşulları (eldiven, güneş ışığı, tek elle kullanım, düşük teknik yetkinlik) göz önünde bulundurularak:

- Büyük dokunma alanları
- Büyük yazılar
- Yüksek kontrast
- Sade ikonlar
- Minimum form alanı
- Akıllı varsayılanlar
- Otomatik tarih/saat doldurma
- Otomatik numaralandırma
- Açık ve anlaşılır hata mesajları

> **Temel ilke:** Kullanıcı mümkün olduğunca az yazmalıdır.

## 3. Form Tasarımı

Formlar aşamalı açılır (progressive disclosure) prensibiyle tasarlanmalıdır. Örnek — Yeni İş formu (ilk ekran):

```
Müşteri     [ABC Market]
İş Türü     [Kamera]
Talep       [________________]
Öncelik     [Yüksek]
Tarih       [20 Ağustos]
Saat        [18:00]

[ İŞİ OLUŞTUR ]
```

Gereksiz/ileri seviye alanlar ilk ekranda **gösterilmemeli**, bir **"Daha Fazla"** bölümü altında toplanmalıdır.

## 4. Arama

Global arama tek bir arama kutusundan tüm varlık tiplerini kapsamalıdır. Örneğin `"ABC"` yazıldığında:

Müşteri · İş · Belge · Servis · Tahsilat sonuçları birlikte listelenir.

## 5. Filtreleme

**İşler ekranı:** Tarih · Durum · İş türü · Müşteri · Teknisyen · Öncelik

**Finans ekranı:** Tarih · Gelir/gider · Kategori · Müşteri · Ödeme durumu

## 6. Mobil Teknoloji Yığını (Flutter)

```
Flutter
├── Riverpod / State Management
├── GoRouter
├── Dio
├── Local Database
├── Secure Storage
├── Camera
├── PDF
├── Signature
└── Notifications
```

> State management ve yardımcı kütüphaneler, proje başlangıcında güncel ve stabil seçenekler değerlendirilerek **kesinleştirilecektir** — yukarıdaki liste yönlendirici bir başlangıç noktasıdır, nihai kütüphane seçimi Phase 4 (Flutter Foundation) sırasında dokümante edilmelidir.

## Mobil Uygulama Otomatik Güncelleme (OTA)

> **Zorunlu gereksinim:** Uygulama Play Store dışında (doğrudan APK dağıtımı, WhatsApp/link ile paylaşım vb.) yayılacağı için, kullanıcı **hiçbir zaman uygulamayı elle kaldırıp yeniden kurmak zorunda kalmamalıdır.** Her güncelleme, mevcut kurulumun üzerine sorunsuzca uygulanabilmelidir.

### Neden "yeniden kurulum gerekmez"

Android, aynı **imza anahtarıyla (signing key)** imzalanmış bir APK'nın üzerine güncelleme kurulumuna izin verir; bu durumda:

- Uygulama verileri (offline veritabanı, secure storage, oturum) **korunur**.
- Kullanıcı yalnızca standart Android "Yükle" onay ekranını görür — **kaldır/yeniden kur adımına gerek yoktur.**
- Bunun çalışabilmesi için **her sürümün aynı release keystore ile imzalanması zorunludur** — keystore kaybı/değişimi, tüm kullanıcı tabanının elle yeniden kurulum yapmasını gerektirir ve **geri dönüşü olmayan bir hatadır.** Keystore güvenli ve yedekli saklanmalıdır.

> **Durum (2026-08-18):** Release keystore oluşturuldu ve iki bağımsız yerde (yerel makine + sunucuda `/root/serviscep_secrets/`, root-only) yedeklendi. Dosyalar `.gitignore` ile repoya **asla** girmez (`android/key.properties`, `android/app/*.jks`). İlk imzalı test sürümü `v0.1.0` olarak yayınlandı (bkz. [ROADMAP.md](../ROADMAP.md)).

### Mekanizma

```
Mobil Uygulama                         Backend
      │                                    │
      │  GET /api/v1/app/version           │
      │ ──────────────────────────────────►│
      │                                    │
      │  { latest_version, min_supported,  │
      │    apk_url, release_notes,         │
      │    force_update }                  │
      │◄────────────────────────────────── │
      │                                    │
      │  (yeni sürüm varsa) APK indir      │
      │ ──────────────────────────────────►│  GitHub Releases (aşağıya bkz.)
      │                                    │
      │  Android PackageInstaller ile      │
      │  kur (mevcut kurulumun üzerine)    │
```

- **Kontrol noktası (mevcut geçici çözüm):** Backend `app/version` endpoint'i henüz yok. Bunun yerine uygulama, Dashboard açılışında GitHub'ın **kendi herkese açık Releases API**'sini (`api.github.com/repos/.../releases/latest`) doğrudan sorgular (bkz. `lib/core/services/update_checker.dart`), mevcut sürümle karşılaştırır ve yeni sürüm varsa bir banner gösterir ("v0.2.1 çıktı — Güncelle" butonu doğrudan APK indirme linkini açar). Bu, backend'e ihtiyaç duymadan gerçek "otomatik güncelleme tespiti" sağlar. Backend Phase 3 derinleştiğinde bu, sunucu tabanlı `app/version` sorgusuna geçirilecektir (force-update, min_supported_version gibi ek kontroller o zaman eklenir) — arayüz (UpdateBanner) değişmeden kalır.
- **APK barındırma — GitHub Releases:** Play Store'da yayın yapılamadığı MVP döneminde (lisanslama süreci tamamlanana kadar), APK sunucuda değil **GitHub Releases** üzerinde barındırılır:
  - Her sürüm, repo üzerinde bir GitHub Release olarak yayınlanır (`vX.Y.Z` tag'i, APK dosyası release asset'i olarak eklenir).
  - GitHub'ın **sabit "latest" URL deseni** kullanılır, böylece tek bir bağlantı her zaman en güncel sürümü çözer — yeni sürüm çıktığında link **değişmez**:
    ```
    https://play.google.com/store/apps/details?id=com.cicibyte.serviscep
    (NOT 2026-08-23: GitHub Release/APK kanalı kapatıldı — dağıtım yalnızca Google Play)
    ```
  - Bu URL hem showroom'daki "İndir" butonunda (bkz. [13 — Web Arayüzü ve Showroom § APK İndirme](13-web-arayuzu-ve-showroom.md#2-apk-i̇ndirme-play-store-yerine)) hem de backend'in `app/version` endpoint'inin döndürdüğü `apk_url` alanında **aynı sabit link** olarak kullanılabilir — ayrı bir dosya barındırma/güncelleme adımına gerek kalmaz.
  - Sunucu tarafında `/releases/` altında statik dosya barındırma, yalnızca GitHub Releases'e erişilemeyen bir senaryoda yedek plan olarak değerlendirilebilir.
- **Force update:** `min_supported_version`'ın altında kalan istemciler, güncelleme yapılmadan API'yi kullanamaz — kritik güvenlik/veri modeli değişikliklerinde bu mekanizma kullanılır.
- **İzin gereksinimi:** Play Store dışı kurulum olduğu için Android'de `REQUEST_INSTALL_PACKAGES` izni gerekir; kullanıcıya bu adım açıkça anlatılmalıdır.
- Bu akış [08 — Offline-First ve Senkronizasyon](08-offline-first-ve-senkronizasyon.md) ile birlikte çalışır: güncelleme kontrolü de bağlantı geldiğinde tetiklenen arka plan işlerinden biridir.

## Push Notification (Zorunlu)

> **Zorunlu gereksinim:** Hatırlatmalar (bkz. [05 — Takvim, Bildirim ve İletişim](05-takvim-bildirim-iletisim.md)) yalnızca uygulama içi değil, **push notification** ile de iletilmelidir — kullanıcı uygulamayı açık tutmadan bildirim almalıdır.

- **Sağlayıcı:** Firebase Cloud Messaging (FCM) — Android için standart, ücretsiz, Flutter ile birinci sınıf entegrasyon.
- Cihaz kaydı: uygulama girişinde FCM device token backend'e kaydedilir (`device_tokens` tablosu — `user_id`, `company_id`, `token`, `platform`, `last_seen_at`).
- Sunucu tarafında zamanlanmış bir job (ör. Laravel scheduled command), hatırlatma kurallarını (§29 — servis randevusu, tahsilat, teklif takibi, garanti bitişi vb.) tarayıp ilgili kullanıcılara push gönderir.
- Uygulama offline iken push ulaşamaz — cihaz tekrar online olduğunda bekleyen/okunmamış bildirimler bir `notifications` listesi üzerinden senkronize edilmelidir (push, tek başına güvenilir teslimat kanalı değildir).

## Web Arayüzü (Panel + Showroom)

Mobil uygulamaya ek olarak bir **web arayüzü** planlanmaktadır — hem herkese açık bir tanıtım/showroom sitesi hem de mobil ile aynı API'yi tüketen bir web paneli. Detaylı kapsam için bkz. **[13 — Web Arayüzü ve Showroom](13-web-arayuzu-ve-showroom.md)**.

## 7. Backend Yapısı (Laravel)

```
app/
├── Models
├── Services
├── Actions
├── Policies
├── Http
│   ├── Controllers
│   ├── Requests
│   └── Resources
├── Jobs
├── Events
├── Listeners
└── Notifications
```

> **Kritik kural:** Business logic **controller içinde dağınık şekilde tutulamaz.** İş kuralları `Services`/`Actions` katmanında toplanır; `Controllers` yalnızca HTTP orkestrasyonundan (request → action → resource) sorumludur.

API tasarım prensipleri için bkz. [07 — API ve Veritabanı](07-api-ve-veritabani.md).

## 8. Performans

Mobil tarafta:

- Lazy loading
- Pagination
- Image compression
- Thumbnail üretimi
- Cache
- Background sync

Fotoğraflar sunucuya yüklenmeden önce **uygun çözünürlüğe küçültülmelidir.**

## Fotoğraf Optimizasyonu

Mobil fotoğraf akışı sabit bir pipeline izlemelidir:

```
Camera → Resize → Compress → Upload Queue → Storage
```

Orijinal (ham) çözünürlükteki fotoğraf her durumda saklanmak **zorunda değildir** — depolama maliyeti ve senkronizasyon süresi optimize edilmelidir.

## Dashboard Verisi

Dashboard, tek bir "dev" API response'una bağımlı olmamalıdır. İhtiyaca göre ayrıştırılmış endpointler (`summary`, `today`, `payments`, `jobs`) kullanılabilir veya performans için optimize edilmiş özel bir dashboard endpoint'i tasarlanabilir. Karar, gerçek kullanım verisiyle (yük, gecikme) doğrulanmalıdır.
