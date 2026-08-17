# ServisCEP — Yol Haritası

> Kaynak: orijinal spesifikasyon §57–§60, §92–§93. Ayrıntılı kapsam dışı liste için bkz. [docs/12-mvp-kapsami.md](docs/12-mvp-kapsami.md).

Bu yol haritası iki eksende organize edilmiştir:

1. **Faz sırası (Phase 1–20)** — geliştirme ajanının/ekibin uyacağı **zorunlu, sıralı** uygulama sırası.
2. **Sprint gruplaması (Sprint 1–8)** — fazların, teslim edilebilir kilometre taşlarına gruplanmış hali.

> ⚠️ **Kural:** Bir faz, [Definition of Done](docs/11-gelistirme-prensipleri.md#definition-of-done-bitmiş-sayılma-kriteri) kriterlerinin tamamını karşılamadan bir sonraki faza geçilmez.

```
MVP  ──────────────────────────────────────────►  V2  ──►  V3 (SaaS)  ──►  V4 (AI)
Tekil işletme, İbrahim'in                         Operasyonel   Çok kiracılı   Akıllı
gerçek kullanımı                                   derinlik      genişleme      otomasyon
```

---

## MVP — Faz Sırası (Phase 1–20)

> **Öncelik notu (2026-08-18):** Kullanıcı kararıyla **mobil uygulama backend'den daha yüksek öncelikli**. Backend (Phase 3) şimdilik yalnızca temel/çalışır iskelet düzeyinde tutulacak; asıl derinlik Flutter tarafında (Phase 4+) ilerleyecek. Bu, Sprint gruplamasını değil, faz içi efor dağılımını etkiler.

| Faz | Kapsam | Sprint | Durum |
|---|---|---|---|
| **1** | Project Architecture — repo yapısı, ortam kurulumu, temel konvansiyonlar | Sprint 1 | ✅ Tamamlandı |
| **2** | Database Schema — PostgreSQL şeması, migration altyapısı (bkz. [docs/07](docs/07-api-ve-veritabani.md)) | Sprint 1 | Sırada |
| **3** | Laravel API Foundation — proje iskeleti, katman yapısı (bkz. [docs/06 § Backend](docs/06-teknik-mimari.md#7-backend-yapısı-laravel)) | Sprint 1 | 🟡 Temel iskelet hazır, derinlik ertelendi |
| **4** | Flutter Foundation — proje iskeleti, state management/routing seçimi | Sprint 1 | 🟡 İskelet + tema + Dashboard hazır, **v0.1.0 test APK'sı yayınlandı** |
| **5** | Authentication — token tabanlı kimlik doğrulama | Sprint 1 |
| **6** | Company Profile — şirket/kullanıcı kurulumu, `company_id` izolasyonunun temeli | Sprint 1 |
| **7** | Customer Management — müşteri CRUD, tipler, profil (bkz. [docs/02](docs/02-is-alani-ve-veri-modeli.md)) | Sprint 2 |
| **8** | Service Request — talep modülü, talep→iş dönüşümü | Sprint 2 |
| **9** | Job / Service Management — iş modülü, durum akışı, iş türleri | Sprint 2 |
| **10** | Service Form — servis formu oluşturma ve doldurma (bkz. [docs/03](docs/03-servis-ve-belge-yonetimi.md)) | Sprint 3 |
| **11** | Photo + Signature — fotoğraf sistemi, dijital imza | Sprint 3 |
| **12** | Quote / Proforma — teklif ve proforma modülleri | Sprint 4 |
| **13** | PDF Engine — belge PDF üretimi, belge merkezi | Sprint 4 |
| **14** | Income / Expense — gelir/gider modülleri (bkz. [docs/04](docs/04-finans-ve-stok.md)) | Sprint 5 |
| **15** | Payments — tahsilat modülü, finans dashboard | Sprint 5 |
| **16** | Offline Engine — yerel veritabanı, offline CRUD (bkz. [docs/08](docs/08-offline-first-ve-senkronizasyon.md)) | Sprint 6 |
| **17** | Synchronization — sync queue, conflict handling, backup | Sprint 6 |
| **18** | Notifications — hatırlatmalar, bildirimler, takvim | Sprint 7 |
| **19** | WhatsApp Sharing — Android Share entegrasyonu, harita | Sprint 7 |
| **20** | Real User Testing — gerçek kullanıcı testi, bug fixing, performans, release build | Sprint 8 |

## MVP — Sprint Özeti

### Sprint 1 — Temel Altyapı
Flutter projesi · Laravel API · Authentication · Company · User · Database · Temel navigation · Dashboard

### Sprint 2 — Müşteri ve İş Çekirdeği
Müşteriler · Müşteri profili · Adresler · İşler · Talepler

### Sprint 3 — Sahada Servis
Servis formu · Fotoğraf · Not · Dijital imza · Servis durumları

### Sprint 4 — Ticari Belgeler
Teklif · Proforma · PDF · Belge merkezi

### Sprint 5 — Finans
Gelir · Gider · Tahsilat · Finans dashboard

### Sprint 6 — Offline & Senkronizasyon
Offline database · Sync engine · Conflict handling · Backup · Error handling

### Sprint 7 — İletişim ve Zamanlama
WhatsApp sharing · Bildirimler · Takvim · Harita

### Sprint 8 — Sahaya Çıkış
Gerçek kullanıcı testleri · Bug fixing · UX iyileştirmeleri · Performance · Release build

> **MVP kabul kriteri:** [docs/11 § Gerçek Hayat Test Senaryosu](docs/11-gelistirme-prensipleri.md#gerçek-hayat-test-senaryosu) uçtan uca, internetsiz başlayıp senkronize ve PDF paylaşımıyla biten senaryo eksiksiz çalışmalıdır.

---

## V2 — Operasyonel Derinlik

MVP'nin gerçek kullanımından gelen geri bildirimlerle önceliklendirilecek genişletmeler:

- Stok yönetimi (tam kapsamlı)
- Malzeme takibi
- Garanti ve bakım periyotları (bkz. [docs/05 § Garanti ve Bakım](docs/05-takvim-bildirim-iletisim.md#6-garanti-ve-bakım-v2))
- Gelişmiş randevu/takvim
- Gelişmiş raporlar (bkz. [docs/04 § Raporlar](docs/04-finans-ve-stok.md#3-finans-dashboard))
- Personel yönetimi
- Rol bazlı yetkilendirme (`ADMIN`, `TECHNICIAN`, `ACCOUNTING`, `VIEWER` — bkz. [docs/09](docs/09-guvenlik-ve-yetkilendirme.md#1-yetkilendirme-roller))
- Web paneli — kapsamlı feature-parity hedefli tam sürüm (erken başlayan showroom/W1-W2 track'i için bkz. [Ek Gereksinimler](#ek-gereksinimler-sonradan-eklenen) ve [docs/13](docs/13-web-arayuzu-ve-showroom.md))
- Çoklu cihaz desteği
- Cloud sync geliştirmeleri

## V3 — SaaS Dönüşümü

Ürün-pazar uyumu doğrulandıktan sonra genel SaaS ürününe geçiş (bkz. [docs/10 — SaaS Vizyonu](docs/10-saas-vizyonu.md)):

- Self-servis SaaS onboarding
- Abonelik modeli (Free / Pro / Business)
- Tam çok kiracılı (multi-tenant) mimari
- Çoklu şirket yönetimi
- Personel/rol genişlemesi
- Genel API erişimi
- E-posta / SMS bildirimleri
- WhatsApp Business API entegrasyonu
- Resmi e-Fatura / e-Arşiv entegrasyonları
- Online ödeme altyapısı

## V4 — Akıllı Otomasyon (AI)

Uzun vadeli vizyon — sesle/doğal dille servis kaydı ve akıllı öneriler (bkz. orijinal spesifikasyon §51–§52 → [docs/99](docs/99-orijinal-spesifikasyon.md)):

- AI ile servis kaydı oluşturma (doğal dil → yapılandırılmış kayıt)
- AI ile teklif oluşturma (öneri + taslak, onay kullanıcıda kalır)
- AI destekli raporlama
- Sesli kullanım
- Akıllı fiyat önerileri
- Otomatik müşteri takibi
- Tahsilat tahmini
- İş kârlılık analizi

---

## Ek Gereksinimler (Sonradan Eklenen)

Aşağıdaki maddeler, orijinal spesifikasyonun (`docs/99`) ötesinde, geliştirme süreci başladıktan sonra netleşen ve **bağlayıcı** hale gelen gereksinimlerdir. Ana Phase 1-20 sırasını değiştirmez, ona **ek/genişletme** olarak eklenir.

| Gereksinim | Kapsam | İlgili Faz | Detay |
|---|---|---|---|
| **APK Otomatik Güncelleme (OTA)** | Kullanıcı hiçbir güncellemede uygulamayı elle kaldırıp yeniden kurmak zorunda kalmamalı | Phase 4 (Flutter Foundation) + Phase 18 (Notifications) ile birlikte devreye alınır | [docs/06 § Mobil Uygulama Otomatik Güncelleme](docs/06-teknik-mimari.md#mobil-uygulama-otomatik-güncelleme-ota) |
| **Push Notification (zorunlu)** | Hatırlatmalar uygulama kapalıyken de push ile iletilmeli (FCM) | Phase 18 (Notifications) — kapsam genişletildi | [docs/06 § Push Notification](docs/06-teknik-mimari.md#push-notification-zorunlu) |
| **Web Arayüzü (Showroom + Panel)** | Mobile ek olarak web tanıtım sitesi + tam işlevsel web panel | Paralel track (W1-W4) — bkz. aşağıda | [docs/13 — Web Arayüzü ve Showroom](docs/13-web-arayuzu-ve-showroom.md) |
| **Google OAuth (Sign in with Google)** | E-posta/parolaya ek kimlik doğrulama yöntemi | Phase 5 (Authentication) — kapsam genişletildi | [docs/09 § Kimlik Doğrulama Yöntemleri](docs/09-guvenlik-ve-yetkilendirme.md#0-kimlik-doğrulama-yöntemleri) |
| **Marka Kimliği (Logo/İkon)** | Logo, favicon, renk paleti — Phase 1 öncesi tamamlandı ✅ | Phase 1 (Project Architecture) öncesi | [docs/14 — Marka Kimliği](docs/14-marka-kimligi.md) |
| **APK İndirme (GitHub Releases)** | Play Store yerine, showroom'dan tek tıkla her zaman en güncel APK indirme | W4 (Showroom) + Phase 18-19 (OTA update ile paylaşılan mekanizma) | [docs/13 § APK İndirme](docs/13-web-arayuzu-ve-showroom.md#2-apk-i̇ndirme-play-store-yerine) |
| **Cari Hesap (Müşteri Ekstresi)** | Özet bakiye yerine tam kronolojik borç/alacak hareketleri + PDF ekstre. Yalnızca müşteri carisi (tedarikçi MVP dışı) | Phase 7 (Customer Management) + Phase 15 (Payments) ile birlikte | [docs/15 — Cari Hesap](docs/15-cari-hesap.md) |

### Web Arayüzü — Paralel Faz Sıralaması

```
W1  Showroom (statik tanıtım sayfası)        ──► bağımsız, hemen başlanabilir (kuruldu ✅)
W2  Login/Signup entegrasyonu                ──► Phase 5 sonrası
W3  Web Panel (mobil ile feature parity)     ──► Phase 9+ sonrası, kademeli
W4  Mobil showcase görselleri showroom'a     ──► Sprint 8 / MVP release sonrası
```

> W1 için sunucu altyapısı zaten hazır — bkz. [deploy/README.md](deploy/README.md). Statik placeholder sayfa, showroom tasarımı netleşince onunla değiştirilecektir.

---

## İlkeler

- Her faz, MVP kapsamındaki [Definition of Done](docs/11-gelistirme-prensipleri.md#definition-of-done-bitmiş-sayılma-kriteri) kriterlerini eksiksiz karşılamalıdır.
- V2/V3/V4 kapsamındaki hiçbir madde, MVP'nin veri modelini veya güvenlik prensiplerini (bkz. [docs/09](docs/09-guvenlik-ve-yetkilendirme.md)) geriye dönük olarak bozacak şekilde uygulanamaz.
- MVP'de bilinçli olarak dışarıda bırakılan kapsam için bkz. [docs/12-mvp-kapsami.md](docs/12-mvp-kapsami.md).
