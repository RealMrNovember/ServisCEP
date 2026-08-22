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

## Backend Mimarisi — Güncel Durum (2026-08-21)

> Bu bölüm, Phase 3'ün gerçek durumunu yansıtır — aşağıdaki "Faz Sırası" tablosundaki Phase 3 satırı artık **güncel değildir**, bilgi burada tutulur.

Backend, iki katmanlı olarak ilerliyor ve **her ikisi de kalıcı, birbirini tamamlayan parçalar** (biri diğerinin yerine geçmiyor):

1. **Filament tabanlı web/admin paneli** — şirket (tenant) paneli (`/panel`) ve admin paneli, Companies/Customers/Jobs/Quotes/Proformas/Products/Warranties/Personnel/Plans/PaymentRequests/Settings kaynakları, abonelik sistemi (14 günlük deneme + admin onaylı ödeme talebi), Google OAuth web akışı. Bu katman zaten oldukça olgun; docRoot ve production HTTPS ayarları yapılmış durumda.
2. **Mobil için JSON REST API** (`/api/v1/*`, Sanctum token) — 2026-08-21'de eklenmeye başlandı. Web panelinin kullandığı **aynı veri modelini** (Company/Customer/Job/...) tüketir, ayrı bir veri kopyası değildir.

> **Production runtime (2026-08-22):** PHP çalışma zamanı, sunucudaki diğer projelerle tutarlı olacak şekilde Docker'a taşındı (`serviscep-php`, `/www/dk_project/serviscep/`) — nginx host'ta aaPanel yönetiminde kalıyor, yalnızca PHP execution container'a geçti. Postgres bare-metal kalmaya devam ediyor; container erişimi `host.docker.internal` + dar kapsamlı `pg_hba.conf`/UFW kurallarıyla sağlandı. `deploy/apply.sh` ve sunucu crontab'ı artık `docker exec serviscep-php ...` kullanıyor. Detaylar: [backend/README.md § Production Runtime](backend/README.md#production-runtime-docker).

| # | Adım | Kapsam | Durum |
|---|---|---|---|
| **B1** | Test altyapısı | `phpunit.xml` (sqlite in-memory), Docker üzerinden çalıştırma (bkz. [backend/README.md](backend/README.md)) | ✅ Tamamlandı ve doğrulandı |
| **B2** | API routing + Sanctum wiring | `routes/api.php`, `bootstrap/app.php`'de `api:` girişi | ✅ Tamamlandı ve doğrulandı |
| **B3** | Authentication API | Register (web'deki `RegisterCompany` ile aynı `Company::startTrial()` akışı), Login, Logout, Me | ✅ Tamamlandı ve doğrulandı (24/24 test yeşil — kayıt sonrası hemen giriş dahil, çifte parola hash'leme riskine karşı regresyon testi eklendi) |
| **B4** | Customer API + izolasyon testi | `/api/v1/customers` CRUD, `CustomerPolicy`, iki şirketin verisinin karışmadığını kanıtlayan testler | ✅ Tamamlandı ve doğrulandı |
| **B5** | Authorization katmanı (genişletme) | `CustomerPolicy` kalıbı kuruldu, `ServiceRequestPolicy`/`JobPolicy` ile tekrarlandı | ✅ Kalıp tüm mevcut kaynaklarda uygulanıyor |
| **B6** | ServiceRequest + Job API | `/api/v1/service-requests` + `/api/v1/jobs` CRUD, talep→iş dönüşümü (`POST .../convert`, bkz. docs/02) | ✅ Tamamlandı ve doğrulandı (43/43 test yeşil, izolasyon + dönüşüm testleri dahil) |
| **B7** | Servis formu + medya API | JobNote/JobPhoto/JobSignature upload, dosya erişim kontrolü (bkz. docs/09 §3) | ✅ Tamamlandı ve doğrulandı (56/56 test yeşil + production smoke test) — dosyalar `local` disk'te (`storage/app/private`, public değil), üçlü erişim: yetkili API çağrısı + süreli imzalı URL + izin kontrolü. Production'da gerçek bir hata bulundu/düzeltildi: `trustProxies` eksikliği (Cloudflare arkasında şema yanlış çözülüyordu) imzalı URL'lerin her zaman 403 dönmesine yol açıyordu |
| **B8** | Ticari belge + finans API | Quote/Proforma (kalemli, KDV/iskonto hesaplı), Payment (otomatik ALACAK), İş tamamlama (otomatik BORÇ), CustomerLedgerEntry (liste + manuel düzeltme), IncomeEntry/ExpenseEntry | ✅ Tamamlandı ve doğrulandı (80/80 test yeşil + production smoke test) — bkz. [docs/15](docs/15-cari-hesap.md). PDF ekstre üretimi (`ledger/statement`) kapsam dışı bırakıldı — Phase 13 (PDF Engine) altyapısı henüz yok |
| **B9** | Güvenlik sertleştirme + Audit Log | docs/09 § 2 Güvenlik Kontrol Listesi'nde açıkça istenen ama B1-B8'de eksik bırakılan maddeler: API rate limiting, Audit Log, "silme yerine İPTAL" ilkesi | ✅ Tamamlandı ve doğrulandı (85/85 test yeşil + production smoke test) — bkz. detaylar aşağıda |
| **B10** | Senkronizasyon motoru | Version tabanlı optimistic concurrency, sync_conflicts, idempotent client-ID create, Customer geri dönüşüm kutusu, mobil outbox + SyncService (Phase 16-17) | ✅ Backend + mobil (Customer+Job dikey dilimi) tamamlandı ve doğrulandı — bkz. detaylar aşağıda |

### B9 Detayları

- **API rate limiting** — `/auth/register` + `/auth/login`: IP başına dakikada 10 istek. Kimliği doğrulanmış tüm API: kullanıcı başına dakikada 120 istek.
- **Audit Log** (`audit_logs` tablosu, immutable) — kritik işlemler kayıt altına alınıyor: müşteri oluştur/güncelle/sil, teklif/proforma oluştur, tahsilat, iş tamamlama/iptal, cari hesap manuel düzeltmesi. `GET /api/v1/audit-logs` yalnızca OWNER erişimine açık.
- **"Silme yerine İPTAL" düzeltmesi** — `Job` için hard-delete endpoint'i (B6'da yanlışlıkla eklenmişti) kaldırıldı; docs/09 § Veri Silme Prensibi'ne uygun olarak durum `IPTAL` yapılarak "silinir".

### B10 Detayları — Backend Yarısı

> Tetikleyici karar: naif "last write wins" güvenli değil — telefon ağdan düşüp offline yazmaya devam ederken ofis aynı kaydı değiştirirse, sessiz ezilme veri kaybına yol açar. Bu yüzden **sürüm tabanlı optimistic concurrency + çakışma kaydı + geri dönüşüm kutusu** modeli kuruldu; mobil taraf aynı modele göre inşa edilecek (bkz. Pending: Mobil Senkron Motoru).

- **Version tabanlı optimistic concurrency** — Customer/Job/ServiceRequest/Quote/Proforma artık bir `version` sayacı taşıyor (`HasVersion` trait, model seviyesinde — API veya Filament, hangi yoldan güncellenirse güncellensin artar). Güncelleme isteği `base_version` göndermek zorunda; sunucudaki version farklıysa güncelleme **reddedilir** (409), sessizce ezilmez.
- **`sync_conflicts` tablosu + çözüm API'si** — her reddedilen güncelleme `incoming_payload` + `server_snapshot` ile birlikte kaydedilir. `GET /api/v1/sync-conflicts` (OWNER-only) bekleyen çakışmaları listeler, `POST .../resolve` ile `SUNUCU_TUTULDU` (mobilin isteği atılır) veya `MOBIL_TUTULDU` (mobilin verisi uygulanır) seçilir — otomatik/sessiz çözüm yok, karar her zaman insan onayına düşer.
- **Idempotent client-ID create** (`AcceptsClientGeneratedId`) — tüm 11 create endpoint'i isteğe bağlı client-generated UUID kabul ediyor; mobilin offline oluşturduğu kaydın ID'si korunur (aksi halde `job.customer_id` gibi ilişkiler senkron sonrası kopardı). Aynı ID ile retry (ağ kesintisi sonrası), var olan kaydı 200 ile döndürür — duplicate oluşturmaz.
- **Customer geri dönüşüm kutusu** — silinen müşteri `GET /customers/trash`'te görünür kalır, `POST /customers/{id}/restore` ile geri yüklenir. Günlük `customers:purge-trash` görevi (sunucu crontab'ına eklendi, `schedule:list` ile doğrulandı), 3+ gündür silinmiş VE hiç iş/teklif/proforma/tahsilat/cari hareket geçmişi olmayan müşterileri kalıcı siler; gerçek geçmişi olan bir kayıt asla otomatik silinmez.
- **Doğrulama** — 99/99 test yeşil (Docker) + canlı production'da tam senaryo koşuldu: ofis günceller → telefon eski version ile yazmaya çalışır → 409 + çakışma kaydı; client-ID ile create → replay → 200 (duplicate yok); sil → trash'te görün → restore. Test verisi sonrasında temizlendi.
- API Resource'larına eksik olan `version` alanı eklendi (`CustomerResource`/`JobResource`/`ServiceRequestResource`/`QuoteResource`/`ProformaResource`) — mobil `base_version` için sunucunun son version'ını bilmek zorunda, model kolonunda vardı ama hiçbir Resource JSON'a yansıtmıyordu.

### B10 Detayları — Mobil Yarısı (kullanıcı kararı: *"Backend + mobil sync motoru birlikte"*)

- **Kapsam**: dikey dilim olarak yalnızca **Customer + Job** senkronlanıyor (ServiceRequest/Quote/Proforma/Payment/Income/Expense/JobNote/Photo/Signature bu iterasyonun dışında — backend'de version/idempotent-create desteği hazır, mobil tarafı ileri bir iterasyona bırakıldı).
- **Auth**: kayıt artık internet gerektiriyor (`AuthRepository.register` backend'e kayıt olur, sunucunun ürettiği `company_id`/`user_id` yerele yazılır — ID uyuşmazlığı hiç oluşmaz). Giriş offline-capable kalıyor: yerelde hesap varsa tamamen offline çalışır, yoksa (yeni cihaz) ve bağlantı varsa backend'den giriş yapılıp yerel DB hazırlanır. Google ile kayıt/giriş hâlâ tamamen yerel — bu hesaplar için `SyncService` token bulamadığından no-op kalır (bilinen sınır, ayrı bir iş).
- **Drift şema göçü (v4)** — `Customers`/`Jobs`'a `version` (backend'in `version`'ının yerel kopyası), yeni `SyncOperations` (outbox) tablosu: her Customer/Job create/update/delete, AYNI transaction içinde bir outbox satırı düşürür — bir yazma asla kuyruğa girmeden yerelde kalmaz.
- **`SyncService`** (`core/sync/sync_service.dart`) — push: outbox'ı sırayla boşaltır, 200/201 → satır silinir + `version`/`syncStatus=SYNCED` güncellenir; 409 → `syncStatus=CONFLICT`, kayıt tekrar denenmez (kullanıcı web panelden çözer veya kaydı yeniden düzenleyip taze bir deneme başlatır); 422 → `FAILED`; ağ hatası → `PENDING` kalır, sessizce yutulmaz. Pull: Customer/Job listeleri çekilir, **yerelde PENDING bir outbox girdisi olan kayıtlar asla ezilmez** — kullanıcının orijinal "telefon offline yazdı, ofis de yazdı" endişesini doğrudan çözen kısım burası.
- **Tetikleme** (`core/sync/sync_trigger.dart`) — bağlantı geldiğinde, uygulama öne geldiğinde ve 3 dakikada bir periyodik.
- **Bilinçli kapsam sınırları** (ROADMAP disiplini gereği açıkça not ediliyor, sessiz eksiklik yok): silinen müşteriler pull listesine girmez (backend'in trash endpoint'i ayrı, tam tombstone senkronu yok); `CustomerLedgerEntries` ne push ne pull ediliyor — mobil kendi BORÇ kaydını yerel oluşturmaya devam ediyor, backend de kendi idempotent BORÇ kaydını ayrı oluşturuyor, iki taraf ayrı hesaplanmaya devam ediyor; mobil taraf çakışma çözüm ekranı yok, kullanıcı web panele yönlendiriliyor.
- **Doğrulama**: `flutter analyze` temiz, 11/11 test yeşil (outbox enqueue, 409→CONFLICT+tekrar denenmeme, pull'un PENDING kaydı ezmediği, `completeWithPrice`'ın cari kaydı senkrona sokmadığı senaryoları dahil). Yerel Windows makinede Flutter SDK yok — tüm build/test/analyze `ghcr.io/cirruslabs/flutter:stable` Docker image'ı üzerinden yapıldı (bkz. [mobile/README.md § Flutter SDK Kurulu Değilse](mobile/README.md#flutter-sdk-kurulu-değilse-docker-ile)).

## MVP — Faz Sırası (Phase 1–20)

> **Öncelik notu (2026-08-18, kısmen güncel değil):** Bu notun yazıldığı tarihte backend gerçekten temel iskeletti; artık değil (yukarıdaki bölüme bakın). Mobil hâlâ birincil kullanıcı deneyimi olmaya devam ediyor, ama backend artık paralel, aktif geliştirilen bir katman.

| Faz | Kapsam | Sprint | Durum |
|---|---|---|---|
| **1** | Project Architecture — repo yapısı, ortam kurulumu, temel konvansiyonlar | Sprint 1 | ✅ Tamamlandı |
| **2** | Database Schema — PostgreSQL şeması, migration altyapısı (bkz. [docs/07](docs/07-api-ve-veritabani.md)) | Sprint 1 | ✅ Tamamlandı |
| **3** | Laravel API Foundation — proje iskeleti, katman yapısı (bkz. [docs/06 § Backend](docs/06-teknik-mimari.md#7-backend-yapısı-laravel)) | Sprint 1 | 🟡 Derinleşiyor — bkz. yukarıdaki **Backend Mimarisi — Güncel Durum** |
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
| **Google Play Dağıtımı** | GitHub Releases'e ek olarak Play Store — Play In-App Update API ile tamamen görünmez güncelleme. Geliştirici hesabı mozkarci1991@gmail.com üzerinden, kapalı test aşamasında (12 test kullanıcısı + 14 gün zorunlu bekleme) | Phase 18-19 (OTA) ile paralel, sonradan eklendi (2026-08-18) | 🟡 **Otomatik sürüm hattı kuruldu ve doğrulandı (2026-08-22)** — `v*` tag'i push'lanınca [release.yml](.github/workflows/release.yml) imzalı AAB'yi Play'e, OTA APK'sını GitHub Release'e yüklüyor (v0.2.9 ile uçtan uca test edildi). Play tarafı şimdilik **dahili test** track'inde: uygulama Console'da taslak durumda olduğu için kapalı teste gerçek sürüm yüklenemiyor — mağaza kurulum görevleri (listing/içerik derecelendirmesi/veri güvenliği, bkz. [docs/17](docs/17-play-store-listesi.md)) tamamlanınca workflow alpha'ya çevrilecek ve 14 günlük kapalı test sayacı başlayacak. `serviscep-test-gurubu@googlegroups.com` grubu kapalı testin testçi listesine API ile bağlandı; test katılım linki: `https://play.google.com/apps/testing/com.cicibyte.serviscep` |
| **Müşteri Belgeleri — Vergi Levhası** | Müşteri profiline vergi levhası gibi resmi belgelerin dosya olarak (PDF/görsel) eklenebilmesi — kesilen teklif/proforma/fatura süreçlerinde referans olarak kullanılır | Phase 7 (Customer Management) genişletmesi — Web Panel Müşteri modülü + Mobil müşteri detayı | Dosyalar [docs/09 § Dosya Güvenliği](docs/09-guvenlik-ve-yetkilendirme.md#3-dosya-güvenliği) prensibiyle `private/company/{company_id}/...` altında, imzalı URL ile erişilebilir tutulmalı — showroom/panel'de asla doğrudan public klasörde saklanmaz |
| **Telefon Rehberinden Müşteri Ekleme (Mobil)** | Müşteri oluşturma ekranında cihazın kişi rehberinden bir kişi seçilip ad/telefon alanlarının otomatik doldurulması | Phase 7 (Customer Management) — mobil taraf genişletmesi | Kişi izni (READ_CONTACTS) + rehber seçici entegrasyonu gerektirir; seçilen kişi verisi yalnızca form doldurmak için kullanılır, ayrıca senkronize edilmez |
| **Stok — Çoklu Tedarikçi ve Garanti Takibi** | Aynı ürün (aynı SKU) farklı tedarikçi/firmalardan alınabilir — her stok girişinde (IN hareketi) tedarikçi firma adı ayrıca kaydedilir, ürün kaydına sabitlenmez. Bir ürün müşteriye monte edildiğinde (işe bağlı), garanti başlangıç/bitiş tarihi ve süresi takip edilir | V2 — Stok yönetimi (tam kapsamlı) ve Garanti ve bakım periyotları maddelerinin somutlaşmış hali | `stock_movements` tablosuna `vendor_name` alanı eklenmesi (bkz. [docs/16 — Stok ve Barkod Modülü](docs/16-stok-ve-barkod.md)); garanti takibi için `Job`/`JobPhoto` ile ilişkili yeni bir `warranty` kaydı — bkz. [docs/05 § Garanti ve Bakım (V2)](docs/05-takvim-bildirim-iletisim.md#6-garanti-ve-bakım-v2) |
| **Hesap Yönetimi (Web Panel)** | Kayıt olan kullanıcılar e-posta adreslerini göremiyor, parolalarını değiştiremiyor, profil fotoğrafı ekleyemiyor — "Hesabım" ekranı eksik | W3 (Web Panel) genişletmesi | ✅ Tamamlandı (2026-08-22) — `EditProfile` sayfası (avatar/isim/parola/e-posta) aslında zaten kuruluydu, yalnızca e-posta değişikliğinin doğrulama akışı (`->emailChangeVerification()`) eksikti, eklendi. Bu arada bağımsız bir sorun bulunup düzeltildi: Filament'in parola sıfırlama + e-posta doğrulama bildirimleri kuyruklu (`ShouldQueue`) ama hiç queue worker yoktu (`QUEUE_CONNECTION=database` → `sync`); ayrıca `MAIL_MAILER=log` bir placeholder'dı (gerçek mail hiç gitmiyordu) — sunucudaki mevcut Postfix/Dovecot mail sunucusunda `serviscep@cicibyte.com` hesabı açılıp gerçek SMTP'ye geçildi, uçtan uca test edildi (kendi kutusuna + gerçek bir Gmail adresine teslim doğrulandı). |

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
