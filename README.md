<div align="center">

<img src="assets/branding/icon-192.png" width="96" height="96" alt="TeknikCEP logosu">

# TeknikCEP

**Saha teknik servis işletmeleri için mobil-first, offline-first işletme yönetim platformu.**

Müşteri → Talep → İş → Servis → Belge → Tahsilat → Finans → Geçmiş

zincirini tek bir mobil uygulamada birleştirir.

[![Durum](https://img.shields.io/badge/durum-planlama-yellow)]()
[![Platform](https://img.shields.io/badge/platform-Android-3DDC84)]()
[![Mobil](https://img.shields.io/badge/mobil-Flutter-02569B)]()
[![Backend](https://img.shields.io/badge/backend-Laravel-FF2D20)]()
[![Veritabanı](https://img.shields.io/badge/veritaban%C4%B1-PostgreSQL-336791)]()
[![Mimari](https://img.shields.io/badge/mimari-Offline--First-blueviolet)]()
[![Lisans](https://img.shields.io/badge/lisans-Proprietary-lightgrey)](LICENSE)

[Dokümantasyon](docs/README.md) · [Yol Haritası](ROADMAP.md) · [Vizyon](docs/01-vizyon-ve-felsefe.md)

</div>

---

## Proje Hakkında

TeknikCEP, elektrik, güvenlik sistemleri (kamera/alarm), bilgisayar/network gibi alanlarda faaliyet gösteren **saha teknik servis işletmelerinin** günlük operasyonunu yönetmek için tasarlanmış bir mobil uygulamadır.

Amaç, "her şeyi yapan dev bir ERP" değil; **sahada çalışan teknik işletmenin telefonunu, işletmenin merkezine dönüştürmektir.** Kullanıcı uygulamayı açtığında ilk göreceği şey her zaman şudur: *"Bugün ne yapacağım?"*

Proje, gerçek bir saha işletmecisinin ihtiyacından yola çıkarak geliştirilmekte; ürün-pazar uyumu doğrulandıktan sonra genel bir **SaaS ürününe** dönüştürülmesi planlanmaktadır.

> Detaylı ürün vizyonu için bkz. [docs/01-vizyon-ve-felsefe.md](docs/01-vizyon-ve-felsefe.md).

## Temel Özellikler

| Alan | Kapsam |
|---|---|
| 👥 **Müşteri Yönetimi** | Bireysel/Firma/Apartman/Site/Kamu müşteri tipleri, tam müşteri profili (finans, iş geçmişi, belgeler, fotoğraflar) |
| 🛠️ **İş / Servis Yönetimi** | Otomatik numaralı iş kayıtları, durum akışı (Talep → Planlandı → Devam Ediyor → Tamamlandı), hazır + özel iş türleri |
| 📋 **Talep Yönetimi** | Müşteri taleplerinin ayrı takibi ve tek tıkla işe dönüştürülmesi |
| 🧾 **Servis Formu & Dijital İmza** | Sahada doldurulan servis formu, parmakla dijital imza, değiştirilemez kayıt |
| 📸 **Fotoğraf Sistemi** | Kategorize edilmiş iş fotoğrafları (öncesi/arıza/montaj/sonrası) |
| 📄 **Teklif & Proforma & Fatura** | Profesyonel PDF belge üretimi, durum takibi, tek noktadan belge merkezi |
| 💰 **Finans Yönetimi** | Gelir/gider takibi, tahsilat durumu, aylık finans dashboard'u |
| 📒 **Cari Hesap** | Müşteri bazlı kronolojik borç/alacak hareketleri, güncel bakiye, PDF ekstre — bkz. [docs/15](docs/15-cari-hesap.md) |
| 📦 **Stok (opsiyonel)** | Servis bazlı malzeme kullanımı ve stok düşümü için hazır veri modeli |
| 🗓️ **Takvim & Bildirimler** | Günlük iş planı, hatırlatmalar, WhatsApp üzerinden belge paylaşımı, push notification (FCM) |
| 🔌 **Offline-First** | Saha ekibi internetsiz tam operasyon; bağlantı geldiğinde otomatik senkronizasyon |
| 🔄 **Otomatik Uygulama Güncelleme** | APK, yeniden kurulum gerektirmeden sunucudan otomatik güncelleme çeker |
| 🌐 **Web Arayüzü** | Herkese açık showroom + mobil ile aynı API'yi kullanan tam işlevsel web paneli — bkz. [docs/13](docs/13-web-arayuzu-ve-showroom.md) |
| 🔐 **Çok Kiracılı Güvenlik** | `company_id` bazlı tam veri izolasyonu, rol bazlı yetkilendirme, dosya erişim kontrolü |
| 🔑 **Kimlik Doğrulama** | E-posta/parola + Google OAuth |

> Tüm modüllerin ayrıntılı tanımı için [docs/](docs/README.md) dizinine bakın.

## Teknoloji Yığını

```
┌─────────────────────────┐     ┌─────────────────────────┐
│         Mobil            │     │         Backend          │
│         Flutter          │◄───►│         Laravel          │
│                          │ API │                          │
│  Riverpod · GoRouter     │     │  Models · Services        │
│  Dio · Local DB          │     │  Actions · Policies       │
│  Secure Storage          │     │  Controllers · Requests   │
│  Camera · PDF · Signature│     │  Jobs · Events            │
│  Notifications           │     │  PostgreSQL               │
└─────────────────────────┘     └─────────────────────────┘
```

| Katman | Teknoloji |
|---|---|
| Mobil | Flutter (Android öncelikli) |
| Backend | Laravel (RESTful, versioned API) |
| Veritabanı | PostgreSQL |
| Mimari | Offline-first, sync-queue tabanlı senkronizasyon |
| İş Modeli | Tekil işletme (MVP) → Çok kiracılı SaaS (V3) |

> Kütüphane seçimleri ve mimari detaylar için bkz. [docs/06-teknik-mimari.md](docs/06-teknik-mimari.md).

## Proje Yapısı

```
ServisCEP/
├── README.md              Bu dosya
├── ROADMAP.md              Geliştirme yol haritası (MVP → V4)
├── LICENSE
├── docs/                   Ürün ve mimari dokümantasyonu
│   ├── README.md           Dokümantasyon indeksi
│   ├── 01-12...            Katman/sektör bazlı dokümanlar
│   └── 99-orijinal-spesifikasyon.md   Arşivlenmiş ilk spesifikasyon
├── deploy/                 Sunucu deploy scripti ve placeholder statik dosyalar
├── backend/                Laravel API (geliştirme başladığında doldurulacak)
└── mobile/                 Flutter uygulaması (geliştirme başladığında doldurulacak)
```

## Dokümantasyon

Proje dokümantasyonu [docs/](docs/README.md) altında katman ve iş alanına göre bölünmüştür:

- [Vizyon ve Felsefe](docs/01-vizyon-ve-felsefe.md)
- [İş Alanı ve Veri Modeli](docs/02-is-alani-ve-veri-modeli.md)
- [Servis ve Belge Yönetimi](docs/03-servis-ve-belge-yonetimi.md)
- [Finans ve Stok](docs/04-finans-ve-stok.md)
- [Takvim, Bildirim ve İletişim](docs/05-takvim-bildirim-iletisim.md)
- [Teknik Mimari](docs/06-teknik-mimari.md)
- [API ve Veritabanı](docs/07-api-ve-veritabani.md)
- [Offline-First ve Senkronizasyon](docs/08-offline-first-ve-senkronizasyon.md)
- [Güvenlik ve Yetkilendirme](docs/09-guvenlik-ve-yetkilendirme.md)
- [SaaS Vizyonu](docs/10-saas-vizyonu.md)
- [Geliştirme Prensipleri](docs/11-gelistirme-prensipleri.md)
- [MVP Kapsamı](docs/12-mvp-kapsami.md)

## Yol Haritası

Geliştirme, MVP odaklı 8 sprint ve 20 fazlık bir sıra izler; MVP sonrası V2 (operasyonel derinlik), V3 (SaaS) ve V4 (AI) aşamaları planlanmıştır.

👉 Detaylar için [ROADMAP.md](ROADMAP.md).

## Geliştirme Prensipleri (Özet)

- Veri modeli ve yetkilendirmede **"sonra düzeltiriz"** yaklaşımı kullanılmaz.
- Para değerleri asla `float` olarak tutulmaz — minor-unit (kuruş) tam sayı yaklaşımı zorunludur.
- Şirket verisi izolasyonu (`company_id`) hiçbir koşulda bozulamaz.
- Yetkilendirme yalnızca frontend'e bırakılmaz; her karar sunucu tarafında doğrulanır.
- Her özellik, backend + API + mobil UI + testler + dokümantasyon tamamlanmadan "bitti" sayılmaz.

👉 Tam liste için [docs/11-gelistirme-prensipleri.md](docs/11-gelistirme-prensipleri.md).

## Proje Durumu

| Alan | Değer |
|---|---|
| Aşama | Planlama |
| MVP | Başlamadı |
| Öncelik | Yüksek |
| Sıradaki Adım | Mimari + Veritabanı + MVP Implementasyonu (bkz. [ROADMAP.md](ROADMAP.md)) |

## Lisans

Bu proje **kapalı kaynaktır** ve tüm hakları saklıdır. Detaylar için [LICENSE](LICENSE) dosyasına bakın.
