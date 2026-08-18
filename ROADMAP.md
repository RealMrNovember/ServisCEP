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

## BUGÜN — Mobil Tamamlama Planı (2026-08-18)

> Kullanıcı kararı: **mobil uygulama bugün uçtan uca çalışır ve profesyonel olmalı** — backend henüz derinleşmeden. Bu bölüm, aşağıdaki Phase 1-20 sırasını **iptal etmez**; onun mobile denk gelen fazlarını (5, 6, 7, 8, 9, 10, 11, 12, 16, 18-kısmi) **yerel-öncelikli (local-first)** bir sırayla, backend bağımlılığı olmadan bugün uygulanabilir hale getirir. Offline-first mimari zaten bunu destekler (bkz. [docs/08](docs/08-offline-first-ve-senkronizasyon.md)) — uygulama yerel veritabanıyla tam işlevsel çalışır, backend senkronizasyonu (Phase 17) ayrı ve sonraki bir katmandır.

**Strateji:** Kimlik doğrulama ve şirket kaydı da dahil her şey önce **yerel veritabanına (Drift)** yazılır. Backend API'si (Phase 3) derinleştiğinde, bu ekranlar değişmeden kalır — yalnızca veri katmanı yerel-only'den yerel+sync'e genişler. Bu, iş tekrarını önler ve "sonra düzeltiriz" riskini taşımaz (bkz. [docs/11](docs/11-gelistirme-prensipleri.md)).

| # | Kapsam | Karşılık gelen Phase | Durum |
|---|---|---|---|
| **M0** | Uygulama adı/etiketi düzeltmesi (Android+iOS: "ServisCEP") | — | ✅ Tamamlandı |
| **M1** | Yerel veritabanı şeması (Drift) — companies, users, customers, jobs, service_requests, quotes, proformas, payments, income, expenses, job_photos, job_signatures, job_notes, customer_ledger_entries | Phase 2 (yerel karşılığı) + Phase 16 | ✅ Tamamlandı |
| **M2** | Kimlik doğrulama & onboarding (yerel-first) — Kayıt (şirket bilgileri + işletme türü + sahip bilgileri + parola), Giriş, oturum kalıcılığı, router yönlendirme | Phase 5 + Phase 6 | ✅ Tamamlandı |
| **M3** | Ana navigasyon iskeleti — Ana Sayfa \| İşler \| Müşteriler \| Belgeler \| Daha Fazla | Phase 4 (genişletme) | ✅ Tamamlandı |
| **M4** | Müşteri modülü — liste, arama/filtre, oluştur/düzenle, detay (Genel/Finans/İş Geçmişi/Belgeler/Fotoğraflar) | Phase 7 | ✅ Tamamlandı |
| **M5** | İş/Servis modülü — liste, filtre, oluştur/düzenle, detay, durum akışı, iş türleri kataloğu, iş tamamlanınca otomatik cari borç kaydı | Phase 9 | ✅ Tamamlandı |
| **M6** | Talep modülü — liste, oluştur, işe dönüştürme (İşler ekranı içinde sekme olarak) | Phase 8 | ✅ Tamamlandı |
| **M7** | Servis Formu + Fotoğraf (kategorili) + Dijital İmza (kamera + signature pad) | Phase 10 + 11 | ✅ Tamamlandı |
| **M8** | **Stok & Barkod Modülü** — ürün kataloğu, stok durumu badge'i (yalnızca uygulama içi), kamera ile barkod okuma + global barkod sorgusu, teklif/proforma kalem seçimi bu katalogdan | Phase 25-26 (genişletilmiş) | ✅ Tamamlandı ([docs/16](docs/16-stok-ve-barkod.md)) — global barkod sağlayıcı entegrasyonu hariç (arayüz hazır, sağlayıcı seçilecek) |
| **M9** | Teklif & Proforma — kalemler M8'deki stok kataloğundan seçilebilir veya serbest girilebilir | Phase 12 | ✅ Tamamlandı |
| **M10** | Finans — Gelir/Gider/Tahsilat + Dashboard'un gerçek veriye bağlanması | Phase 14 + 15 | ✅ Tamamlandı — Finans ekranı (Özet/Gelir/Gider), müşteri detayından tahsilat kaydı (otomatik cari ALACAK) |
| **M11** | Belge Merkezi + PDF üretimi (Teklif, Proforma, Servis Formu) — kurumsal tasarım, WhatsApp/Android Share ile paylaşım | Phase 13 | ✅ Tamamlandı |
| **M12** | Daha Fazla / Ayarlar / Hakkında (BrandFooter, çıkış yap, şirket ayarları) | Phase 6 (genişletme) | ✅ Tamamlandı (temel), ayar alt ekranları sırada |
| **M13** | Takvim görünümü — aylık takvim + günlük iş listesi | Phase 18 (kısmi) | ✅ Tamamlandı |
| **M14** | Yerel hatırlatma bildirimleri (push/FCM değil — cihaz içi zamanlanmış bildirim) — randevudan 30 dk önce, inexact scheduling, durum TAMAMLANDI/İPTAL olunca otomatik iptal | Phase 18 (kısmi) | ✅ Tamamlandı |

> **Dürüst kapsam notu:** M0–M14 tamamlandı ve gerçek cihazda derlenip doğrulandı. M0-M14 kapsamındaki mobil M-listesi bu haliyle tamamlanmış durumda. Sunucu tarafı push bildirimleri (FCM, Firebase proje kurulumu gerektirir — bkz. [docs/06](docs/06-teknik-mimari.md)) ve global barkod sağlayıcı entegrasyonu (bkz. [docs/16](docs/16-stok-ve-barkod.md)) kasıtlı olarak kapsam dışı bırakıldı; bunları "bugün bitti" diye işaretlemeyeceğiz, çünkü gerçekten bitmemiş bir şeyi bitti göstermek profesyonel değildir. Backend senkronizasyonu (Phase 3 derinliği + Phase 17) ve Web Arayüzü (login/signup + panel) ayrı, sonraki büyük fazlar olarak kalır.

---

## MVP — Faz Sırası (Phase 1–20)

> **Öncelik notu (2026-08-18):** Kullanıcı kararıyla **mobil uygulama backend'den daha yüksek öncelikli**. Backend (Phase 3) şimdilik yalnızca temel/çalışır iskelet düzeyinde tutulacak; asıl derinlik Flutter tarafında (Phase 4+) ilerleyecek. Bu, Sprint gruplamasını değil, faz içi efor dağılımını etkiler. Bugünkü yürütme sırası için bkz. yukarıdaki **BUGÜN — Mobil Tamamlama Planı**.

| Faz | Kapsam | Sprint | Durum |
|---|---|---|---|
| **1** | Project Architecture — repo yapısı, ortam kurulumu, temel konvansiyonlar | Sprint 1 | ✅ Tamamlandı |
| **2** | Database Schema — PostgreSQL şeması, migration altyapısı (bkz. [docs/07](docs/07-api-ve-veritabani.md)) | Sprint 1 | Sırada |
| **3** | Laravel API Foundation — proje iskeleti, katman yapısı (bkz. [docs/06 § Backend](docs/06-teknik-mimari.md#7-backend-yapısı-laravel)) | Sprint 1 | 🟡 Temel iskelet hazır, derinlik ertelendi |
| **4** | Flutter Foundation — proje iskeleti, state management/routing seçimi | Sprint 1 | 🟡 Temel + M0-M8 tamamlandı, **v0.2.0 yayınlandı** (auth, müşteri, iş, talep, stok/barkod, foto/imza) |
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
| **Stok & Barkod Modülü** | Teklif/proforma kalemleri stok kataloğundan seçilebilir, stok durumu uygulama içi (belgelerde değil) renkli badge ile gösterilir, kamera ile barkod okuma + global barkod veri kaynağından otomatik ürün bilgisi | M8 (bkz. yukarıdaki BUGÜN planı) — Phase 25-26'nın genişletilmiş hali | [docs/16 — Stok ve Barkod Modülü](docs/16-stok-ve-barkod.md) |

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
