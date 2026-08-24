# TeknikCEP — Mobile (Flutter)

Saha teknik servis işletmeleri için offline-first, mobil-first Android uygulaması.

> **Durum:** Phase 4 (Flutter Foundation) — proje iskeleti, tema, navigasyon ve ana sayfa (Dashboard) kuruldu. Bu, mobil öncelikli geliştirmenin ilk somut adımıdır (bkz. [../ROADMAP.md](../ROADMAP.md)).

## Kurulum

```bash
flutter pub get
flutter run
```

## Flutter SDK Kurulu Değilse (Docker ile)

Yerel makinede Flutter SDK yoksa, `ghcr.io/cirruslabs/flutter:stable` image'ı ile aynı işler yapılabilir. Pub-cache'in her çalıştırmada sıfırlanmaması için kalıcı bir named volume kullanılır:

```powershell
docker volume create serviscep_pub_cache
docker run --rm -v "C:\CiciByte\ServisCEP\mobile:/app" -v serviscep_pub_cache:/root/.pub-cache -w /app ghcr.io/cirruslabs/flutter:stable sh -c "flutter pub get && dart run build_runner build --delete-conflicting-outputs"
docker run --rm -v "C:\CiciByte\ServisCEP\mobile:/app" -v serviscep_pub_cache:/root/.pub-cache -w /app ghcr.io/cirruslabs/flutter:stable flutter analyze
docker run --rm -v "C:\CiciByte\ServisCEP\mobile:/app" -v serviscep_pub_cache:/root/.pub-cache -w /app ghcr.io/cirruslabs/flutter:stable flutter test
```

(Not: Docker Desktop bu ortamda yalnızca **PowerShell**'den erişilebiliyor — bkz. [../backend/README.md](../backend/README.md).) `environment.sdk` kısıtlaması bu image'ın bundle ettiği Dart sürümüne göre (`^3.12.0`) ayarlıdır — pubspec.lock'ta daha yeni bir Dart görülmesi normaldir, geriye dönük uyumluluk bozulmaz.

## Proje Yapısı

```
lib/
├── main.dart               Giriş noktası (ProviderScope + locale init)
├── app/
│   ├── app.dart             MaterialApp.router kurulumu
│   ├── router.dart          GoRouter tanımları
│   └── theme.dart           Marka renkleri + Material 3 tema
└── features/
    ├── dashboard/            Ana sayfa ("Bugün ne yapacağım?")
    ├── customers/            (Phase 7)
    ├── jobs/                 (Phase 9)
    ├── documents/            (Phase 12-13)
    └── finance/              (Phase 14-15)
```

## Teknoloji Yığını

| Katman | Paket |
|---|---|
| State management | `flutter_riverpod` |
| Navigasyon | `go_router` |
| Ağ | `dio` |
| Yerel veritabanı (offline-first) | `drift` + `drift_flutter` |
| Güvenli depolama | `flutter_secure_storage` |
| Bağlantı durumu | `connectivity_plus` |
| Yerelleştirme | `intl` + `flutter_localizations` (tr_TR) |
| Uygulama ikonu | `flutter_launcher_icons` (kaynak: [`assets/icon/app_icon.png`](assets/icon/app_icon.png), bkz. [../docs/14](../docs/14-marka-kimligi.md)) |

Kamera, PDF, dijital imza ve push notification bağımlılıkları, ilgili özellik fazlarında (Phase 11, 13, 18) eklenecektir — bkz. [../docs/06-teknik-mimari.md](../docs/06-teknik-mimari.md).

## Uyulması Gereken Dokümanlar

- Mobil UX prensipleri, "modern ve şık" zorunlu kalite çıtası: [../docs/06-teknik-mimari.md](../docs/06-teknik-mimari.md#2-mobil-tasarım-prensipleri)
- Offline-first mimari ve senkronizasyon: [../docs/08-offline-first-ve-senkronizasyon.md](../docs/08-offline-first-ve-senkronizasyon.md)
- APK otomatik güncelleme (OTA) ve GitHub Releases dağıtımı: [../docs/06 § OTA](../docs/06-teknik-mimari.md#mobil-uygulama-otomatik-güncelleme-ota)
- Servis formu, fotoğraf, dijital imza akışları: [../docs/03-servis-ve-belge-yonetimi.md](../docs/03-servis-ve-belge-yonetimi.md)
- Genel geliştirme prensipleri: [../docs/11-gelistirme-prensipleri.md](../docs/11-gelistirme-prensipleri.md)
