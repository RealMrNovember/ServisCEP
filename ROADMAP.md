# TeknikCEP — Yol Haritası (eski adıyla ServisCEP)

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
| **M0** | Uygulama adı/etiketi düzeltmesi (Android+iOS: "TeknikCEP") | — | ✅ Tamamlandı |
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

> **Dürüst kapsam notu:** M0–M14 tamamlandı ve gerçek cihazda derlenip doğrulandı. M0-M14 kapsamındaki mobil M-listesi bu haliyle tamamlanmış durumda. Global barkod sağlayıcı entegrasyonu (bkz. [docs/16](docs/16-stok-ve-barkod.md)) kasıtlı olarak kapsam dışı bırakıldı (sunucu tarafı push bildirimleri o tarihte kapsam dışıydı, **v0.5.0'da tamamlandı**); bunları "bugün bitti" diye işaretlemeyeceğiz, çünkü gerçekten bitmemiş bir şeyi bitti göstermek profesyonel değildir. Backend senkronizasyonu (Phase 3 derinliği + Phase 17) ve Web Arayüzü (login/signup + panel) ayrı, sonraki büyük fazlar olarak kalır.

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

- **Kapsam**: ilk dilimde yalnızca **Customer + Job** senkronlanıyordu; **dikey dilim 2 (2026-08-24, v0.3.2)** ile kapsam genişletildi:
  - **Push + pull**: Customer, Job, **ServiceRequest, Quote, Proforma** (yerel şema v5: bu üç tabloya `version`/`syncStatus` eklendi; Quote/Proforma kalemleriyle birlikte taşınır, pull'da kalemler sunucudakiyle toptan değiştirilir — kalemler immutable olduğu için güvenli).
  - **Push-only**: **Payment, IncomeEntry, ExpenseEntry** (create-only kayıtlar, çakışma riski yok; web panelde girilen finans kayıtlarının mobile İNMEMESİ bilinçli kapsam sınırı).
  - **Talep → iş dönüşümü senkronu**: backend'in `/convert` endpoint'i artık mobilin offline oluşturduğu işin UUID'sini (`job_id`) kabul ediyor (replay idempotent — aynı talep + aynı job_id 200 döner, duplicate iş oluşmaz). Mobil dönüşümde ayrıca bir job CREATE kuyruklamaz; tek CONVERT operasyonu gider, yanıttaki sunucu türetmesi (kod/başlık/açıklama) yerel işe uygulanır. Bu, dönüşümle oluşan işlerin hiç senkronlanmadığı önceki boşluğu da kapattı.
  - **Medya push-only senkronu (2026-08-24, v0.4.0)**: JobNote/JobPhoto/JobSignature yazmaları da outbox'a düşer; fotoğraf/imza dosyaları payload'da değil, gönderim anında diskten multipart okunur (dosya silinmişse satır FAILED olur, sessizce atlanmaz). Panelde eklenen medya mobile inmez — medya telefonda üretilir, panel görüntüleme yeridir.
  - **Tombstone senkronu + mobil çakışma çözüm ekranı (2026-08-24, v0.4.1)**: Ofiste (web panelde) silinen müşteri artık telefonda da siliniyor — backend'in 3 günlük çöp kutusu penceresi pull'da taranıyor. Bekleyen yerel yazması (PENDING outbox) olan kayıt ATLANIR: kullanıcının offline düzenlemesi sessizce silinmez, önce push edilir. Çakışmalar için mobilde ayrı bir ekran açıldı ("Daha Fazla → Senkron çakışmaları", yalnızca çakışma varken görünen sayaç rozetiyle): ofis ve telefon halleri alan alan yan yana gösterilir (ham JSON değil, okunabilir alan adlarıyla ve yalnızca gerçekten değişen alanlar), kullanıcı "Ofistekini tut" / "Benimkini tut" seçer. Çözüm sonrası yerel CONFLICT izleri temizlenip anında senkron tetiklenir. Kullanıcı artık web paneline yönlendirilmiyor.
  - **Cari hesap (2026-08-24, v0.6.0)**: artık pull-only senkronlanıyor, sunucu tek doğruluk kaynağı — bkz. Ek Gereksinimler tablosundaki "Cari Hesap Senkronu" satırı. Senkron motorunda bilinçli olarak açık bırakılmış nokta KALMADI.
- **Auth**: kayıt artık internet gerektiriyor (`AuthRepository.register` backend'e kayıt olur, sunucunun ürettiği `company_id`/`user_id` yerele yazılır — ID uyuşmazlığı hiç oluşmaz). Giriş offline-capable kalıyor: yerelde hesap varsa tamamen offline çalışır, yoksa (yeni cihaz) ve bağlantı varsa backend'den giriş yapılıp yerel DB hazırlanır.
- **Google ile devam et — sonradan bulunan ve düzeltilen kritik hata (2026-08-22):** Gerçek kullanıcı testinde ortaya çıktı — "Google ile devam et" hiçbir zaman backend'e bağlanmamıştı (tamamen yerel eşleştirme), bu yüzden yerel veri temizlenince (veya yeni bir cihazda) var olan bir hesabı olan kullanıcı zorla sıfırdan kayıt akışına düşüyordu. `POST /auth/google/login` + `POST /auth/google/register` eklendi (web'in Google akışıyla — `AuthService::findOrCreateGoogleUser` — aynı eşleştirme kuralını paylaşıyor, Socialite'in `userFromToken()`'ı ile doğrulama, ek kütüphane gerekmedi). Mobil taraf artık gerçekten Sanctum token alıyor, senkron bu hesaplar için de çalışıyor.
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
| **3** | Laravel API Foundation — proje iskeleti, katman yapısı (bkz. [docs/06 § Backend](docs/06-teknik-mimari.md#7-backend-yapısı-laravel)) | Sprint 1 | ✅ Tamamlandı — Laravel 13 + Sanctum + Filament 5.7 (iki panel), 227 test. Üretimde Docker'da çalışıyor. |
| **4** | Flutter Foundation — proje iskeleti, state management/routing seçimi | Sprint 1 | ✅ Tamamlandı — Riverpod + GoRouter (`StatefulShellRoute`), Drift, 35 ekran, 120 test. Tasarım sistemi v0.7.4'te devreye alındı. |
| **5** | Authentication — token tabanlı kimlik doğrulama | Sprint 1 | ✅ Tamamlandı — Sanctum token'ları, e-posta/parola ve Google ile giriş, kayıt, çıkışta sunucudaki oturumun da kapatılması. Güvenli depo bozulduğunda uygulamanın kullanılamaz hale gelmesi (v0.7.1) ayrıca giderildi. |
| **6** | Company Profile — şirket/kullanıcı kurulumu, `company_id` izolasyonunun temeli | Sprint 1 | ✅ Tamamlandı — Şirket kaydı, ayarlar (ünvan/IBAN/antet/logo), `company_id` izolasyonu her uçta zorunlu; başka şirketin verisine erişim testlerle kapatıldı. |
| **7** | Customer Management — müşteri CRUD, tipler, profil (bkz. [docs/02](docs/02-is-alani-ve-veri-modeli.md)) | Sprint 2 | ✅ Tamamlandı — Bireysel/firma ayrımı, telefon rehberinden ekleme, vergi levhası tarama, cari hesap. Çöp kutusu ve tombstone senkronu dahil. |
| **8** | Service Request — talep modülü, talep→iş dönüşümü | Sprint 2 | ✅ Mobil tamamlandı — Talep formu ve işe dönüştürme (`/convert`), çevrimdışı kuyrukla. **Web'de yok** (bkz. Sıradaki İşler → W3). |
| **9** | Job / Service Management — iş modülü, durum akışı, iş türleri | Sprint 2 | ✅ Tamamlandı — Durum akışı, öncelik, kendi iş türlerini tanımlama, tamamlarken ücret alma (cari hesaba otomatik borç). |
| **10** | Service Form — servis formu oluşturma ve doldurma (bkz. [docs/03](docs/03-servis-ve-belge-yonetimi.md)) | Sprint 3 | ✅ Tamamlandı — `buildServiceFormPdf`; fotoğraf, not ve imzayla birlikte tek belgede. |
| **11** | Photo + Signature — fotoğraf sistemi, dijital imza | Sprint 3 | ✅ Tamamlandı — Fotoğraflar cihazda saklanıp outbox ile yükleniyor, imza ekranda alınıp belgeye basılıyor. **Web'de görüntülenemiyor** (bkz. W3). |
| **12** | Quote / Proforma — teklif ve proforma modülleri | Sprint 4 | ✅ Tamamlandı — Ortak form gövdesi, akıllı belge numarası (son kayıttan devam, ön ek ve sıfır dolgusu korunur, yıl değişince başa döner), gün sayısıyla geçerlilik, hazır şablonlar, TL/USD/EUR, +KDV / KDV dahil. |
| **13** | PDF Engine — belge PDF üretimi, belge merkezi | Sprint 4 | ✅ Mobil tamamlandı — Tek sayfalık kurumsal belge; gömülü Roboto (yerleşik PDF fontları ş/ğ/İ içermiyor), logo kendi oranında, iskonto sütunu yalnızca gerekliyse, KDV oranı satırlardan türetiliyor. **Web'de PDF üretimi YOK** — en büyük eksik (bkz. W3). |
| **14** | Income / Expense — gelir/gider modülleri (bkz. [docs/04](docs/04-finans-ve-stok.md)) | Sprint 5 | ✅ Tamamlandı — Hem mobil hem web panelde. |
| **15** | Payments — tahsilat modülü, finans dashboard | Sprint 5 | ✅ Mobil tamamlandı — Tahsilat cari hesaba otomatik ALACAK olarak işliyor, tek transaction. Aynı tahsilatın bakiyeye iki kez yansıması (v0.6.0) giderildi. **Web'de cari/tahsilat yok** (bkz. W3). |
| **16** | Offline Engine — yerel veritabanı, offline CRUD (bkz. [docs/08](docs/08-offline-first-ve-senkronizasyon.md)) | Sprint 6 | ✅ Tamamlandı — Drift, şema v9. Her yazma önce cihaza gider; internetsiz tam işlevsel. |
| **17** | Synchronization — sync queue, conflict handling, backup | Sprint 6 | ✅ Tamamlandı — Outbox deseni, sürüm tabanlı iyimser eşzamanlılık, pull bekleyen yerel yazmanın üzerine yazmıyor, tombstone senkronu, çakışma çözüm ekranı. **Çakışmalar artık otomatik birleşiyor**: iki taraf farklı alanlara dokunduysa kimse elle karar vermiyor (alan izi + `changed_fields`); elle çözüm yalnızca aynı alan iki tarafta da değiştiğinde gerekiyor. **Yedekleme devrede**: gecelik veritabanı + saha dosyası yedeği, Google Drive'a dış kopya, ayda bir gerçek restore testi. |
| **18** | Notifications — hatırlatmalar, bildirimler, takvim | Sprint 7 | ✅ Tamamlandı — Yerel iş hatırlatmaları (süre ayarlanabilir), FCM push (abonelik onayı/reddi, süre hatırlatması), takvim ekranı. |
| **19** | WhatsApp Sharing — Android Share entegrasyonu, harita | Sprint 7 | ✅ Tamamlandı — Belge WhatsApp/e-posta ile paylaşılıyor, müşteri adresi haritada açılıyor. |
| **20** | Real User Testing — gerçek kullanıcı testi, bug fixing, performans, release build | Sprint 8 | 🟡 Sürüyor — Google Play kapalı testte, otomatik sürüm hattı çalışıyor (v0.7.7). Gerçek kullanımdan gelen hatalar sürümlerle gideriliyor. Play'in 12 testçi / 14 gün şartı henüz karşılanmadı. |

## MVP — Sprint Özeti

### Sprint 1 — Temel Altyapı ✅
Flutter projesi · Laravel API · Authentication · Company · User · Database · Temel navigation · Dashboard

### Sprint 2 — Müşteri ve İş Çekirdeği ✅
Müşteriler · Müşteri profili · Adresler · İşler · Talepler

### Sprint 3 — Sahada Servis ✅
Servis formu · Fotoğraf · Not · Dijital imza · Servis durumları

### Sprint 4 — Ticari Belgeler ✅ (mobil)
Teklif · Proforma · PDF · Belge merkezi

> PDF üretimi web panelde henüz yok — bkz. Sıradaki İşler → W3.

### Sprint 5 — Finans ✅ (mobil)
Gelir · Gider · Tahsilat · Finans dashboard

> Cari hesap ve tahsilat web panelde henüz yok — bkz. W3.

### Sprint 6 — Offline & Senkronizasyon ✅
Offline database ✅ · Sync engine ✅ · Conflict handling ✅ · Backup ✅ · Error handling ✅

> Çakışmaların çoğu artık otomatik çözülüyor; yedekleme her gece alınıp Drive'a
> çıkıyor ve ayda bir gerçekten geri yüklenerek doğrulanıyor.

### Sprint 7 — İletişim ve Zamanlama ✅
WhatsApp sharing · Bildirimler · Takvim · Harita

### Sprint 8 — Sahaya Çıkış 🟡
Gerçek kullanıcı testleri · Bug fixing · UX iyileştirmeleri · Performance · Release build

> Kapalı testte sürüyor. Otomatik sürüm hattı çalışıyor; her sürüm tag ile Play'e gidiyor.

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
| **Google Play Dağıtımı** | Play Store üzerinden dağıtım ve otomatik güncelleme. Geliştirici hesabı mozkarci1991@gmail.com | Phase 18-19 (OTA) ile paralel, sonradan eklendi (2026-08-18) | 🟡 **Kapalı testte, canlı ve otomatik.** `v*` tag'i push'lanınca [release.yml](.github/workflows/release.yml) imzalı AAB'yi + CHANGELOG'dan üretilen sürüm notlarını **alpha (kapalı test)** track'ine yüklüyor. GitHub Releases/APK kanalı 2026-08-22'de kapatıldı — Play tek dağıtım kanalı. Testçi erişimi `serviscep-test-gurubu@googlegroups.com` grubuna bağlı; katılım linki `https://play.google.com/apps/testing/com.cicibyte.serviscep`. **Kalan:** 12 testçi × 14 gün şartı dolunca production'a (herkese açık) geçiş. NOT: Play her sürümü incelemeden geçirir, tag'den sonra kullanıcıya ulaşması birkaç saat sürer. |
| **Müşteri Belgeleri — Vergi Levhası** | Müşteri profiline vergi levhası gibi resmi belgelerin dosya olarak (PDF/görsel) eklenebilmesi — kesilen teklif/proforma/fatura süreçlerinde referans olarak kullanılır | Phase 7 (Customer Management) genişletmesi — Web Panel Müşteri modülü + Mobil müşteri detayı | ✅ Tamamlandı (2026-08-24, v0.4.1) — Web panelde zaten vardı (`tax_certificate_path` FileUpload); mobil/API tarafı eklendi: `POST/GET/DELETE /customers/{id}/tax-certificate` + imzalı indirme linki. Dosya `local` disk'te `tax-certificates/{company_id}` altında, ham yol asla JSON'a sızmaz (yalnızca `has_tax_certificate` + süreli imzalı URL). Mobilde "Belgeler" sekmesi: kamerayla tara (galeri izni yok), yerel kopya + outbox üzerinden yükleme (çevrimdışı çekilebilir). Yeni yükleme öncekinin yerine geçer, eski dosya silinir (yetim dosya bırakmaz). | Dosyalar [docs/09 § Dosya Güvenliği](docs/09-guvenlik-ve-yetkilendirme.md#3-dosya-güvenliği) prensibiyle `private/company/{company_id}/...` altında, imzalı URL ile erişilebilir tutulmalı — showroom/panel'de asla doğrudan public klasörde saklanmaz |
| **Telefon Rehberinden Müşteri Ekleme (Mobil)** | Müşteri oluşturma ekranında cihazın kişi rehberinden bir kişi seçilip ad/telefon alanlarının otomatik doldurulması | Phase 7 (Customer Management) — mobil taraf genişletmesi | ✅ Tamamlandı (2026-08-24, v0.4.1) — **READ_CONTACTS izni İSTENMEDİ**: sistemin kendi kişi seçicisi (`ACTION_PICK`) açılıyor, kullanıcı tek kişiyi kendi iradesiyle seçiyor ve Android yalnızca o kaydın URI'sine geçici okuma hakkı veriyor. Kotlin platform kanalı (`MainActivity.kt`) + `ContactPicker` (Dart) ile, yeni bağımlılık eklemeden. Seçilen veri yalnızca formu doldurur, saklanmaz/senkronlanmaz. Bu tercih bilinçli: kullanılmayan medya izinlerini kaldırma disiplinimizle (v0.2.12) tutarlı, Play politika beyanı gerektirmiyor. |
| **Stok — Çoklu Tedarikçi ve Garanti Takibi** | Aynı ürün (aynı SKU) farklı tedarikçi/firmalardan alınabilir — her stok girişinde (IN hareketi) tedarikçi firma adı ayrıca kaydedilir, ürün kaydına sabitlenmez. Bir ürün müşteriye monte edildiğinde (işe bağlı), garanti başlangıç/bitiş tarihi ve süresi takip edilir | V2 — Stok yönetimi (tam kapsamlı) ve Garanti ve bakım periyotları maddelerinin somutlaşmış hali | `stock_movements` tablosuna `vendor_name` alanı eklenmesi (bkz. [docs/16 — Stok ve Barkod Modülü](docs/16-stok-ve-barkod.md)); garanti takibi için `Job`/`JobPhoto` ile ilişkili yeni bir `warranty` kaydı — bkz. [docs/05 § Garanti ve Bakım (V2)](docs/05-takvim-bildirim-iletisim.md#6-garanti-ve-bakım-v2) |
| **Personel Yönetimi + Rol Yetkilendirmesi** | Herkes OWNER'dı; işletme sahibi çalışanına kısıtlı hesap açamıyordu | V2 → öne çekildi (kullanıcı: "olmadan test ettiremem", 2026-08-24) | ✅ Tamamlandı (v0.6.0) — `RolePermissions` yetki matrisi TEK kaynak; tüm politikalar oradan okur, tanımsız rol hiçbir şeye yetkili değil (fail-closed). İş kuralı: **teknisyen işletmenin finansal verilerini göremez**. `/personnel` uçları yalnızca sahibe açık; kendini silme/rolünü düşürme ve son OWNER'ı kaybetme engellendi, silinen personelin oturum jetonları iptal ediliyor. `Plan::max_users` limiti **artık uygulanıyor** (alan vardı, hiç kontrol edilmiyordu). Mobil: personel ekranı, oturum rol taşıyor, menüde role göre gizleme. Canlıda doğrulandı: teknisyen müşteriyi görüyor (200), gelir/cari/personel uçlarından 403 alıyor. |
| **Cari Hesap Senkronu** | Mobil ve backend cari kayıtlarını BAĞIMSIZ oluşturuyordu — bakiyeler sessizce ayrışabilirdi | B10 senkron motorunun son açık noktası | ✅ Tamamlandı (v0.6.0) — Tek doğruluk kaynağı **sunucu**. Telefon iyimser yerel kayıt tutar (kullanıcı bakiyeyi anında görsün), pull sırasında sunucunun kaydıyla değiştirilir; eşleştirme (reference_type, reference_id) üzerinden yapılır. **Gerçek hata bulundu ve düzeltildi:** mobil tahsilat kaydı referans olarak jobId yazıyordu, sunucu payment.id yazıyor — bu uyumsuzluk yüzünden aynı tahsilat eşleştirilemez ve bakiye ÇİFT sayılırdı. |
| **Sürüm Notları (Play "Yenilikler")** | Her güncellemede kullanıcının ne değiştiğini okuyabilmesi | Sürüm hattı — kullanıcı kararı (2026-08-24) | ✅ Tamamlandı — Tek kaynak `CHANGELOG.md`; her `## vX.Y.Z` bölümü CI tarafından Play "Yenilikler" alanına yazılır. Kural **mekanik olarak zorunlu**: bölüm yoksa, boşsa, bozuksa veya 500 karakteri aşıyorsa `.github/scripts/prepare_release_notes.py` hata verir ve sürüm yayınlanmaz — unutulması mümkün değil. Notlar kullanıcı diliyle yazılır (teknik terim değil, ne kazandığı). v0.5.0 notları geriye dönük olarak yayındaki sürüme de eklendi. |
| **Push Notification (FCM)** | Hatırlatmalar uygulama kapalıyken de iletilmeli | Phase 18 — "zorunlu" işaretliydi | ✅ Tamamlandı (2026-08-24, v0.5.0) — Firebase **tamamen API üzerinden** kuruldu (konsol işlemi gerekmedi): Firebase Management API etkinleştirildi, mevcut GCP projesine Firebase eklendi, Android uygulaması oluşturuldu, `google-services.json` çekildi. Sunucu için owner anahtarı yerine Firebase'in kendi Admin SDK servis hesabının anahtarı kullanılıyor (repoda değil, sunucuda 600 izinle). Backend: `device_tokens` + `POST/DELETE /devices`, `FcmService` (HTTP v1, ek paket bağımlılığı yok — openssl ile JWT imzalama). Gönderim hatası çağıranın işlemini asla bozmaz; kalıcı olarak ölü token'lar silinir, geçici hatalarda kayıt korunur. Tetikleyiciler: ödeme onayı + günlük 10:00'da abonelik süre hatırlatması (3 ve 1 gün kala, her gün değil). Mobil: izin/token/ön plan gösterimi, çıkışta kayıt silme; Firebase yoksa sessizce devre dışı. Production'da FCM kimlik zinciri uçtan uca doğrulandı. |
| **Ayar Ekranları (Mobil)** | "Daha Fazla" menüsündeki Şirket ayarları / İş türleri / Bildirimler kalemleri pasifti | Phase 6 genişletmesi — kullanıcı isteği (2026-08-24) | ✅ Tamamlandı (v0.5.0) — **Şirket ayarları**: ünvan, işletme türü, IBAN (offline yazma + outbox senkronu; IBAN teklif/proforma PDF'lerinde kullanılıyor). **İş türleri**: kullanıcı kendi türlerini ekliyor, iş formundaki otomatik tamamlamayı besliyor (hazır katalog salt okunur kalıyor). **Bildirimler**: hatırlatma süresi artık ayarlanabilir (kapalı/15/30/60/120 dk), tercih kalıcı. "Kullanıcılar ve yetkiler" bilinçli olarak pasif bırakıldı ("Yakında" notuyla) — personel daveti + rol yaptırımı ayrı ve daha büyük bir iş, sahte bir ekran koymak yerine dürüst davranıldı. |
| **Sürüm Numarası Görünürlüğü (Mobil)** | Kullanıcı hangi sürümde olduğunu göremiyordu — güncellemenin gerçekten indiğini doğrulayamıyor | Phase 4 genişletmesi — kullanıcı isteği (2026-08-24) | ✅ Tamamlandı (v0.4.1) — "Daha Fazla" menüsünün en altında, marka atfının altında sessiz bir satır: "Sürüm X.Y.Z (build)". Değer derleme anında pubspec'ten okunur (`package_info_plus`), elle güncellenen bir sabit değildir — gösterilen her zaman gerçekten yüklü olan sürümdür. |
| **Karşılama Akışı (İlk Açılış)** | Uygulama ilk açılışta doğrudan giriş ekranına düşmemeli — kısa, atlanabilir bir tanıtım akışı | Phase 4 (Flutter Foundation) genişletmesi — kullanıcı isteği (2026-08-24) | ✅ Tamamlandı (v0.4.0) — 5 sayfalık, marka kimliğiyle uyumlu (koyu zemin + tek mavi vurgu, docs/14) karşılama akışı; yalnızca oturum YOKKEN ve yalnızca BİR KEZ gösterilir (`welcome_seen_v1`). Var olan oturumla açılış "görüldü" sayılır — çıkış yapan kullanıcı tanıtıma düşmez. |
| **Abonelik Yaptırımı (Enforcement)** | Süresi dolan/askıya alınan şirketin erişimi nazikçe kesilmeli — yaptırım olmadan abonelik sistemi fiilen dekoratifti (`hasActiveSubscription()` yalnızca gösterimde kullanılıyordu) | docs/10 SaaS Vizyonu — abonelik sisteminin tamamlayıcısı | ✅ Tamamlandı (2026-08-24, v0.3.3) — API: `subscription.active` middleware'i veri uçlarında 402 + `SUBSCRIPTION_EXPIRED` döner; kimlik (me/logout) ve yenileme uçları (plans/subscription/payment-requests) bilinçli olarak açık kalır. Web panel: süresi dolan kullanıcı yalnızca Abonelik sayfasını görür, diğer GET'ler oraya yönlendirilir (Livewire/logout POST'ları serbest — ödeme bildirimi formu çalışmaya devam eder). Mobil: 402'de senkron kuyruğu PENDING kalır (veri kaybolmaz, yenileme sonrası akar), abonelik durumu her senkron döngüsünde tazelenir (banner "sona erdi" kademesine anında geçer); ayrıca pull hatalarının unawaited exception sızdırması boşluğu kapatıldı. |
| **Hesap Yönetimi (Web Panel)** | Kayıt olan kullanıcılar e-posta adreslerini göremiyor, parolalarını değiştiremiyor, profil fotoğrafı ekleyemiyor — "Hesabım" ekranı eksik | W3 (Web Panel) genişletmesi | ✅ Tamamlandı (2026-08-22) — `EditProfile` sayfası (avatar/isim/parola/e-posta) aslında zaten kuruluydu, yalnızca e-posta değişikliğinin doğrulama akışı (`->emailChangeVerification()`) eksikti, eklendi. Bu arada bağımsız bir sorun bulunup düzeltildi: Filament'in parola sıfırlama + e-posta doğrulama bildirimleri kuyruklu (`ShouldQueue`) ama hiç queue worker yoktu (`QUEUE_CONNECTION=database` → `sync`); ayrıca `MAIL_MAILER=log` bir placeholder'dı (gerçek mail hiç gitmiyordu) — sunucudaki mevcut Postfix/Dovecot mail sunucusunda `serviscep@cicibyte.com` hesabı açılıp gerçek SMTP'ye geçildi, uçtan uca test edildi (kendi kutusuna + gerçek bir Gmail adresine teslim doğrulandı). |

| **Tasarım Sistemi (Mobil)** | Uygulama görsel olarak dağınıktı; koyu tema açık temanın renk çevrimi gibi duruyordu, gövde metni saha koşulları için küçüktü | Phase 4 genişletmesi — dış tasarım desteği (2026-08-25) | ✅ Tamamlandı (v0.7.4–v0.7.6) — 45 renk tokeni `ThemeExtension` olarak, koyu tema kendi yüzey merdiveniyle. İki aksan tokeni bilinçli: marka rengi `#3B82F6` beyaz yazı altında 3.68:1 verip AA'yı geçmiyor, dolgular `accentSolid` kullanıyor. `ColorScheme` artık `fromSeed` yerine paletten üretiliyor — 90 çağrı yerindeki okuma 34 ekranı dolaşmadan yeni renklere geçti. Üç gömülü font (Archivo/Barlow/JetBrains Mono, OFL), 93 ikonluk SVG set, hareket spesifikasyonu. Kontrast iddiaları testle kilitlendi. **JetBrains Mono'da ₺ glifi yok** — tutar stillerine Roboto yedeği bağlandı, aksi halde her tutarda kutucuk çıkacaktı. |
| **Çevrimdışı Göstergeleri** | Kullanıcı verisinin sunucuya gidip gitmediğini göremiyordu; bir sürümde arayüz saatlerce "her şey eşitlendi" yazdı ama sunucuya hiç ulaşılamıyordu | docs/06 offline-first — güven katmanı (2026-08-25) | ✅ Tamamlandı (v0.7.5–v0.7.6) — Üst şerit dört durumlu: çevrimdışı / eşitleniyor / bekliyor / gizli. "Eşitleniyor" YALNIZCA gerçek bir tur çalışırken yazılıyor; bunun için `SyncService`'e gerçek bir çalışıyor sinyali eklendi. Kuyrukta kayıt olması gönderiliyor olmak değildir. Şerit kaydırarak kapatılabiliyor ama durum değişir ya da bekleyen sayısı ARTARSA geri geliyor. Liste ekranlarının üst çubuğunda bekleyen kayıt rozeti; sayı sıfırken tamamen kayboluyor. Ham exception metni basan altı hata dalı anlaşılır hata ekranına çevrildi. |
| **Sürüm Takibi (Destek)** | Kullanıcı sorun bildirdiğinde hangi sürümde olduğu sorulmadan bilinemiyordu | Destek ihtiyacı — kullanıcı isteği (2026-08-26) | ✅ Tamamlandı (v0.7.6) — Kök sebep: sunucu `X-App-Version` başlığını zaten okuyup `app_logs`'a yazıyordu ama **mobil uygulama bu başlığı hiç göndermiyordu**; üretimdeki 21 günlük satırının 21'inde de sürüm sütunu boştu. Uygulama artık her isteğe sürüm künyesi ekliyor; bilgi kullanıcıya KALICI yazılıyor (günlükler budandığı için oradan okumak yetmez), 15 dakikada bir tazeleniyor. Panelde kullanıcı listesinde sürüm rozeti + "eski sürümde" filtresi, şirket listesinde "en eski sürüm (N kişi geride)". |
| **Kartla Abonelik Ödemesi** | Tahsilat IBAN havalesi + elle onayla yürüyordu; ödeme akışı uygulama içine alınmalı | docs/10 SaaS — kullanıcı kararı (2026-08-26, PayTR başvurusu) | ✅ Altyapı tamamlandı — Sağlayıcı anahtarları panelden girilene kadar sistem HAVALE kipinde kalır, girildiği anda kart kipine geçer; kip kodla değil yapılandırmayla değişiyor, anahtarlar geldiğinde yeni sürüm gerekmiyor. "Etkin" işareti tek başına yetmiyor: anahtarlardan biri eksikse kart kipine geçilmiyor. PayTR iFrame API resmî dokümana göre uygulandı, kart bilgisi sunucumuza hiç uğramıyor. Tutar SUNUCUDA hesaplanıyor; doğrulanmamış bildirim hiçbir şeyi değiştirmiyor; mükerrer bildirimde abonelik ikinci kez uzamıyor. **Karşılığı olmayan ama imzası geçerli bildirimler SAHİPSİZ durumuyla kayda alınıyor** — günlükler budanır, para hareketi budanmamalı. Yedi noktada loglama + panelde Kart Ödemeleri tablosu. **Kart ödeme akışı (mobil) henüz yok**: anahtarsız yazmak yalnızca derlendiğini görmek olurdu. |
| **Plan Süresi (Panelden Yönetim)** | Panelde girilen "Süre (gün)" hiçbir yerde kullanılmıyordu | Abonelik sisteminin düzeltmesi (2026-08-26) | ✅ Tamamlandı — Kod sabit 1 ay / 12 ay ekliyordu: panelde 90 gün yazan bir pakete ödeme yapan müşteri 30 gün alıyor ve kimse fark etmiyordu. Aylık ve yıllık için AYRI alanlar eklendi; tek alan olsaydı yıllık `duration_days × 12` olur, 30 günlük pakette 360 gün ederdi ve müşteri sessizce 5 gün kaybederdi. Üç uzatma yolu (kart, havale onayı, elle uzatma) artık aynı hesaptan geçiyor. |
| **Ödeme Bildirimleri ve Geçmişi** | Ödeme talebi reddedildiğinde kullanıcı bundan HİÇ haberdar olmuyordu | Kullanıcı isteği (2026-08-26) | ✅ Tamamlandı (v0.7.7) — Onay bildirim gönderiyordu, red göndermiyordu; kullanıcı havalesini yapmış ve cevap bekliyordu, parasının ne olduğunu bilmeden. Red artık bildirim gönderiyor. Yöneticinin notu müşteriye ULAŞIYOR — onayda yazılan açıklama ("gönderdiğin tutar şu pakete yetti") panelde kalıyordu. Not hem bildirimde hem kayıtta duruyor: bildirim kaybolur, kayıt kalır. Mobilde "Ödemelerim" ekranı: kart ve havale bir arada, BEKLEYENLER ayrı bölümde ve üstte — bekleyen talep cevap beklenen bir şey, geçmiş yalnızca referans. |
| **Marka İşareti Yenileme** | Mevcut logo beğenilmiyordu | Marka (2026-08-26) | ✅ Uygulama simgesi tamamlandı (v0.7.7) — Dört yön arasından "Plaka" seçildi: kesik köşeli ekipman künyesi, negatif alanda T. Gerekçe en yüksek siyah alana sahip olması — PDF antedinde gri tonlamada ve 16px favicon'da en okunaklı kalan bu. Kalan yüzeyler: PDF anteti, favicon, tanıtım sitesi. |
| **Belge Düzeltmeleri (KDV/Antet)** | Karma KDV oranlı belgede yanlış beyan; "KDV dahil" belgelerde tutar şişmesi | Belge motoru düzeltmeleri (2026-08-25/26) | ✅ Tamamlandı (v0.7.5) — Kalem editörü satır başına KDV oranı seçtiriyordu ama belge tek orandan söz ediyordu; oran artık satırlardan türetiliyor, karma ise "her satırda belirtilen oranda" deniyor. **Sunucu "KDV dahil" belgelerde KDV'yi ikinci kez ekliyordu**: ₺1.200'lük belge senkron sonrası ₺1.440 oluyor ve cihazdaki doğru tutarın üzerine yazılıyordu — mobil bu ayrımı yapıyordu, sunucu yapmıyordu. Mükerrer geçerlilik tarihi kaldırıldı; ödeme bilgisi bloğu artık her belgede yer alıyor (IBAN yoksa iletişim bilgisiyle). |

## Sıradaki İşler (2026-08-26 itibarıyla)

Bu bölüm aktif takip içindir. Biten madde işaretlenir, açıklaması
yukarıdaki tablolara taşınır.

### W3 — Web/Mobil Eşitliği

Ayrıntılı envanter: [docs/20-web-mobil-esitlik.md](docs/20-web-mobil-esitlik.md)

- [ ] **Belge PDF'i (web)** — Web'den teklif/proforma oluşturulabiliyor ama
      belge üretilemiyor. En büyük eksik: teklifin varlık sebebi o belge.
      İki motorun AYNI belgeyi üretmesi şart.
- [ ] **Cari hesap + tahsilat (web)** — `CustomerResource` altında hiç
      ilişki yöneticisi yok; bakiye ve hareketler web'den görülemiyor.
- [ ] **İş detayı: fotoğraf/imza görüntüleme + tamamlama (web)** — Web'in
      iş formu düz CRUD. Fotoğraf ÇEKMEK web'de anlamsız ama GÖRMEK
      değerli: ofis sahayı ancak böyle görüyor.
- [ ] **Servis talepleri (web)** — Web'de hiç yok.
- [ ] **İş türleri (web)**
- [ ] **Senkron çakışmaları (web)** — Çakışmayı mobil üretiyor, çözecek
      kişi genelde ofiste.
- [ ] **Garantiler (mobil)** — Ters yönde eksik: web'de var, mobilde yok.

Web'e taşınmayacaklar (cihaza özgü): barkod tarama, rehberden müşteri
ekleme, fotoğraf çekme, bildirim süresi ayarı, senkron durumu ekranı.

### Ödeme Sistemi

- [x] Kart ödemesi altyapısı — PayTR iFrame, havale/kart kip anahtarı,
      sahipsiz tahsilat koruması, yedi noktada loglama (2026-08-26)
- [ ] **Kart ödeme akışı (mobil)** — Sağlayıcı anahtarları girildikten ve
      GERÇEKTEN test edilebildikten sonra. Anahtarsız yazmak yalnızca
      derlendiğini görmek olurdu.
- [ ] Kayıtlı kart — PayTR'ye sorulacak: iFrame sayfasında kullanıcıya
      kart hatırlatma var mı? Yoksa Direkt API gerekir ve o, kart verisini
      bizim sunucumuza sokar (PCI). Bu hâliyle önerilmiyor.

### Tasarım (0.8.0)

- [x] Tasarım sistemi tokenları, bileşen katmanı, yeni alt menü
- [x] Yeni marka işareti — uygulama simgesi
- [ ] **42 ekranın yeniden düzeni** — Asıl iş. Tasarımcının teslimatı hazır.
- [ ] Logo'nun kalan yüzeyleri: PDF anteti, favicon, tanıtım sitesi
- [ ] Adımlı teklif formu (4 adım)
- [ ] İkon göçü — 176 çağrı yeri Material'dan tasarım setine

### Belge

- [ ] **Ücretsiz pakette belge altbilgisi** — "TeknikCEP ile hazırlandı".
      Sıfır maliyetli müşteri kanalı + paket yükseltme sebebi.
- [ ] **Yüzde iskonto** — Backend hazır (`discount_rate`), mobil Drift
      şeması v9 → v10 bekliyor. Altbilgiyle aynı göçte yapılacak.
- [ ] Toplam iskonto satırı — Tasarımda var, PDF'te yok.

### Büyüme (değerlendirilecek)

- [ ] **Tahsilat** — Kullanıcının kendi müşterisinden tahsilat; ödeme
      bağlantısı + vadesi geçen alacak hatırlatması. Müşteriye para
      kazandıran özellik en kolay satılandır.
- [ ] **İş devri ağı** — Firmalar birbirine iş gönderebilsin; karşı taraf
      TeknikCEP'te değilse SMS ile davet. Büyüme motoru. Sohbet DEĞİL.
- [ ] Bildirim merkezi + zil — Ancak iş devri ağıyla birlikte anlamlı;
      tek başına içi boş kalır.

### Bakım

- [x] **Yedekleme** (2026-08-26) — Veritabanının yedeği YOKTU: sunucudaki
      yedekleme betiği yalnızca Docker container'ı olarak çalışan
      Postgres'leri buluyor, TeknikCEP'inki çıplak kurulu olduğu için
      taramaya hiç girmiyordu. Artık her gece 02:30'da veritabanı +
      saha dosyaları alınıp mevcut Drive akışına bırakılıyor; ayın 1'inde
      son yedek boş bir container'a gerçekten geri yükleniyor ve şirket
      sayısı doğrulanıyor. Hatalar Telegram'a düşüyor. Kurulumda 13
      şirket geri yüklenerek kanıtlandı. `.env` bilinçli olarak yedeğe
      girmiyor — bedeli `deploy/README.md`'de yazılı: APP_KEY kaybolursa
      şifreli sütunlar geri getirilemez.
- [x] **Otomatik çakışma çözümü** (2026-08-26) — Sürüm uyuşmazlığı "aynı
      anda düzenlendi" demek, "aynı ŞEY düzenlendi" demek değildi; yine de
      hepsi elle çözülüyordu. Artık iki taraf farklı alanlara dokunduysa
      güncelleme otomatik birleşiyor. İki bilgi gerekiyordu: istemcinin
      neyi değiştirdiği (`changed_fields`) ve sunucunun neyi değiştirdiği
      (`field_changes` izi, sürüm sayacıyla aynı yerde tutuluyor ki panel
      üzerinden yapılanlar da kapsansın). Bilgi eksikse — eski istemci ya
      da budanmış iz — çakışma kaydediliyor: eksik bilgiyle birleştirmek,
      bu mekanizmanın engellemek için var olduğu şeyin ta kendisi olurdu.
- [x] **Sürüm kaydını CI yazıyor** (2026-08-26) — Elle giriliyordu ve bir
      kez unutuldu: 0.7.5 Play'e çıktı, sunucu "sürüm yok" dediği için
      kimseye güncelleme bildirimi gitmedi. Yayın hattı artık yüklemeden
      sonra sunucuya bildiriyor (paylaşılan jeton; jeton yoksa uç KAPALI).
- [x] **Eskimiş CI action'ları** (2026-08-26) — `track` parametresi
      action tarafından kullanımdan kaldırılmıştı; yerine `tracks` geldi.
      Eski alan bir gün kalksa sürüm yayınlamak tamamen kırılırdı.
      checkout ve setup-java v5'e çekildi.
- [x] **`CalculatesDocumentTotal` tekilleştirildi** (2026-08-26) — İki
      dosyada duruyor, elle eşit tutuluyordu; proje aynı hatayı abonelik
      süresinde bir kez yaşamıştı. Tek `DocumentTotal` sınıfına toplandı.
      Bu arada bir tuzak da kapandı: `discount_rate` saklanıyor ama
      toplama hiç yansımıyordu.
> Mobil tarafta `changed_fields` gönderen tüm yollar kapsandı: müşteri ve
> iş güncellemeleri (alan farkı hesaplanarak), iş/teklif durum
> değişiklikleri ve iş tamamlama (değişen alanlar zaten kodda belli).
> Proforma ve servis talebi mobilden hiç güncelleme kuyruğuna girmiyor;
> sunucudaki uçları `changed_fields` kabul ediyor, kullanan olduğunda
> hazır.

---

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
