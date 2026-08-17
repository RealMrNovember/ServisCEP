# Orijinal Spesifikasyon (Arşiv)

> **Not:** Bu dosya, projenin ilk taslak dokümanı olan `idea.md`'nin değiştirilmeden arşivlenmiş halidir. İçerik, [docs/](README.md) altındaki katman/sektör bazlı dokümanlara bölünmüştür. Güncel geliştirme için önce ilgili konu dokümanına bakın; bu dosya yalnızca tarihsel referans ve izlenebilirlik amaçlıdır — **düzenlenmemelidir**.

---

Aşağıdaki dosya, projeyi İbrahim abinin gerçek kullanım senaryosundan başlayıp ileride SaaS ürününe dönüşebilecek şekilde tasarlıyor.

# ServisCEP
- Adres
- İl
- İlçe
- Vergi bilgileri
- Notlar
- Etiketler

## Müşteri Tipleri

- Bireysel
- Firma
- Apartman
- Site
- Kamu
- Diğer

---

# 10. MÜŞTERİ PROFİLİ

Müşteri açıldığında:

## Genel

- İletişim
- Adres
- Notlar

## Finans

- Toplam iş tutarı
- Tahsil edilen
- Bekleyen
- Toplam borç

## İş Geçmişi

Tüm servisler kronolojik gösterilir.

## Belgeler

- Teklifler
- Proformalar
- Servis formları
- Tahsilatlar
- Faturalar

## Fotoğraflar

Müşteriye bağlı tüm iş fotoğrafları.

---

# 11. İŞ / SERVİS MODÜLÜ

Her iş benzersiz bir numaraya sahip olmalıdır.

Örnek:

`SRV-2026-000142`

## İş Durumları

```text
TALEP
PLANLANDI
DEVAM EDİYOR
BEKLEMEDE
TAMAMLANDI
İPTAL
```

İş Bilgileri:
- İş numarası
- Müşteri
- İş türü
- Başlık
- Açıklama
- Adres
- Randevu tarihi
- Başlangıç zamanı
- Bitiş zamanı
- Öncelik
- Durum
- Teknisyen
- Tahmini fiyat
- Gerçek fiyat
- Notlar

# 12. İŞ TÜRLERİ

Sistem hazır iş türleriyle gelmelidir.

**Elektrik**
- Arıza
- Tesisat
- Aydınlatma
- Priz
- Sigorta
- Kablo
- Montaj
- Bakım

**Güvenlik Sistemleri**
- IP Kamera
- Analog Kamera
- DVR
- NVR
- Alarm
- İnterkom
- Access Control
- Kamera bakımı
- Kamera arızası
- Kamera kurulumu

**Bilgisayar**
- Format
- Windows kurulumu
- SSD değişimi
- RAM değişimi
- Donanım arızası
- Yazılım kurulumu
- Virüs temizleme
- Bakım

**Network**

**Diğer**

Kullanıcı özel iş türü oluşturabilmelidir.

# 13. TALEP MODÜLÜ

Müşteri tarafından gelen talepler ayrı olarak tutulmalıdır.

Örnek:

TALEP #REQ-2026-00152

Müşteri: ABC Market

Talep: 3 kamera görüntü vermiyor.

Öncelik: Yüksek

Adres: Kadıköy / İstanbul

Durum: Bekliyor

Talep daha sonra doğrudan işe dönüştürülebilmelidir.

# 14. SERVİS FORMU

TeknikOS'un en önemli belgelerinden biridir.

Servis Formu:

SERVİS FORMU

Servis No: SRV-2026-00142

Müşteri: ABC Market

Servis Tarihi: 20.08.2026

Arıza / Talep: 3 kamera görüntü vermiyor.

Tespit: PoE bağlantısında problem bulundu.

Yapılan İşlemler:
- PoE switch kontrol edildi.
- RJ45 bağlantıları yenilendi.
- Kamera adaptörü değiştirildi.

Kullanılan Malzemeler:
2 x RJ45
1 x 12V Adaptör

Servis Ücreti: 1.500 TL

Malzeme: 850 TL

Toplam: 2.350 TL

Alt bölüm:
- Müşteri imzası
- Teknisyen imzası
- Tarih

# 15. DİJİTAL İMZA

Müşteri telefonda/parmakla imza atabilmelidir.

İmza:
- Servis kaydına bağlanır.
- PDF'e eklenir.
- Değiştirilemez kayıt olarak saklanır.

İmzanın hukuki niteliği konusunda sistem resmi elektronik imza yerine geçiyormuş gibi pazarlanmamalıdır.

# 16. FOTOĞRAF SİSTEMİ

Her iş için fotoğraf eklenebilmelidir.

Fotoğraf Kategorileri:
- İş Öncesi
- Arıza
- Montaj
- İş Sonrası
- Malzeme
- Diğer

Fotoğraflar iş kaydıyla ilişkilendirilmelidir.

# 17. PROFORMA MODÜLÜ

Proforma oluşturma akışı:

Yeni Proforma → Müşteri → Kalemler → Miktar → Birim fiyat → KDV → İskonto → Toplam → Notlar → PDF

Proforma Alanları:
- Belge numarası
- Tarih
- Geçerlilik tarihi
- Firma bilgileri
- Müşteri bilgileri
- Ürün/hizmet
- Miktar
- Birim
- Birim fiyat
- İskonto
- KDV
- Ara toplam
- Genel toplam
- IBAN
- Açıklama
- Ödeme şartları

# 18. TEKLİF MODÜLÜ

Teklif proformadan ayrı bir belge tipi olarak tasarlanmalıdır.

Örneğin:

TEKLİF

8 Adet IP Kamera
1 Adet NVR
1 Adet PoE Switch
2 TB HDD
Cat6 Kablo
Montaj ve İşçilik

TOPLAM: 56.500 TL

Teklif durumları:

TASLAK
GÖNDERİLDİ
BEKLEMEDE
KABUL EDİLDİ
REDDEDİLDİ
SÜRESİ DOLDU

# 19. BELGE MERKEZİ

Tüm belgeler tek noktadan yönetilmelidir.

Belgeler:
```
├── Proformalar
├── Teklifler
├── Servis Formları
├── Faturalar
├── Tahsilat Belgeleri
├── Garanti Belgeleri
└── Diğer
```

Filtre:
- Müşteri
- Tarih
- Belge tipi
- Durum
- Tutar

# 20. FATURA YAKLAŞIMI

MVP'de resmi e-Fatura sistemi oluşturulmayacaktır.

İlk aşamada:
- Fatura kaydı
- Fatura numarası
- Fatura tarihi
- Müşteri
- Tutar
- KDV
- Ödeme durumu
- PDF
- Dosya arşivi

desteklenecektir.

Resmi e-Fatura / e-Arşiv entegrasyonu daha sonraki fazda ayrı bir entegrasyon olarak ele alınacaktır.

# 21. TAHSİLAT MODÜLÜ

Her işin ödeme durumu tutulmalıdır.

Durumlar:
ÖDENMEDİ
KISMİ ÖDENDİ
ÖDENDİ

Örnek:

İş Tutarı: 8.500 TL

Tahsil Edildi: 5.000 TL

Kalan: 3.500 TL

# 22. GELİR MODÜLÜ

Gelirler manuel olarak veya işle ilişkilendirilerek oluşturulabilir.

Alanlar:
- Tarih
- Açıklama
- Müşteri
- İş
- Kategori
- Tutar
- Ödeme yöntemi
- Not

Gelir Kategorileri:
Servis, Malzeme, Montaj, Bakım, Danışmanlık, Diğer

# 23. GİDER MODÜLÜ

Gider alanları:
- Tarih
- Açıklama
- Kategori
- Tutar
- Firma
- Fiş/fatura fotoğrafı
- Ödeme yöntemi
- Not

Gider Kategorileri:
Malzeme, Yakıt, Araç, Kargo, Telefon, İnternet, Ekipman, Ofis, Personel, Diğer

# 24. FİNANS DASHBOARD

Aylık görünüm:

```
Gelir       ₺82.450
Gider       ₺31.250
-------------------
Net         ₺51.200
```

Ek raporlar:
Günlük gelir, Haftalık gelir, Aylık gelir, Yıllık gelir, Gider dağılımı, Tahsilat durumu, Müşteri bazlı ciro, İş türü bazlı ciro, Kârlılık

# 25. STOK MODÜLÜ

MVP'de zorunlu değildir.

Ancak veri modeli başlangıçtan itibaren stok desteğine uygun olmalıdır.

Ürün:
SKU, Barkod, Ürün adı, Marka, Model, Kategori, Birim, Alış fiyatı, Satış fiyatı, Mevcut stok, Minimum stok

Örnek:
RJ45 Konnektör — 142 adet
Cat6 Kablo — 315 metre
IP Kamera 5MP — 8 adet

# 26. MALZEME KULLANIMI

Bir servis sırasında:
2 x RJ45
1 x 12V Adaptör
10 metre Cat6

kullanıldığında stoktan düşülebilmelidir.

Bu işlem servis kaydıyla ilişkilendirilmelidir.

# 27. RANDEVU / TAKVİM

Takvim ekranı:

```
AĞUSTOS 2026

18 Salı — 3 İş
19 Çarşamba — 2 İş
20 Perşembe — 4 İş
```

Her iş: Saat, Müşteri, Adres, İş tipi, Öncelik bilgilerini göstermelidir.

# 28. HARİTA

Müşteri adresinde "Haritada Aç" butonu bulunmalıdır.

Gelecekte: "Bugünkü İşler → Harita" özelliği geliştirilebilir.

# 29. HATIRLATMALAR

Sistem şu hatırlatmaları desteklemelidir:
Servis randevusu, Tahsilat, Teklif takibi, Garanti bitişi, Periyodik bakım, Müşteri geri dönüşü, Planlanan iş

# 30. WHATSAPP PAYLAŞIMI

MVP'de doğrudan WhatsApp Business API kullanılmasına gerek yoktur.

Android Share mekanizması kullanılmalıdır.

Örnek: Servis formu PDF → Paylaş → WhatsApp

Mesaj şablonu:

```
Merhaba Ahmet Bey,

Bugün gerçekleştirdiğimiz servis işlemine ait
servis formunuzu ekte iletiyorum.

Teşekkür ederiz.
```

# 31. PDF MOTORU

Belgeler profesyonel görünmelidir.

Her PDF: Firma logosu, Firma bilgileri, Müşteri bilgileri, Belge numarası, Tarih, Ürün/hizmet tablosu, KDV, Toplam, IBAN, Açıklama, İmza alanlarını desteklemelidir.

PDF tasarımı sade, modern ve kurumsal olmalıdır.

# 32. BELGE ŞABLONU SİSTEMİ

İleride kullanıcı kendi şablonlarını seçebilmelidir.

Örneğin: Şablon A (Minimal), Şablon B (Kurumsal), Şablon C (Teknik Servis), Şablon D (Klasik)

Firma logosu ve renkleri otomatik uygulanabilir.

# 33. OFFLINE-FIRST MİMARİ

Bu proje için kritik gereksinimdir.

Saha ortamında internet olmayabilir.

Bu nedenle kullanıcı: Müşteri oluşturabilmeli, İş oluşturabilmeli, Servis formu doldurabilmeli, Fotoğraf çekebilmeli, Not yazabilmeli, Tahsilat kaydedebilmeli

ve internet olmadan çalışabilmelidir.

Veriler lokal veritabanına kaydedilir.

İnternet geldiğinde:

```
LOCAL → SYNC QUEUE → API → SERVER
```

senkronizasyon yapılır.

# 34. SENKRONİZASYON

Her lokal işlem PENDING olarak tutulur.

Sunucuya başarıyla gönderildiğinde SYNCED olur.

Hata durumunda FAILED olur.

Kullanıcıya teknik hata göstermek yerine "3 kayıt senkronizasyon bekliyor." gibi sade bilgi gösterilmelidir.

# 35. VERİTABANI ANA MODELİ

Temel tablolar:

```
users, companies, company_settings

customers, customer_addresses, customer_contacts

service_requests, jobs, job_notes, job_photos, job_materials, job_signatures

quotes, quote_items

proformas, proforma_items

invoices, invoice_items

payments, income, expenses

products, stock_movements

documents, document_templates

appointments, reminders

audit_logs, sync_operations
```

# 36. ŞİRKET BAZLI VERİ AYRIMI

Sistem SaaS'a dönüşeceği için tüm işletme verileri `company_id` ile ayrılmalıdır.

Bir şirket: Başka şirketin müşterisini, Başka şirketin işini, Başka şirketin finansını, Başka şirketin belgelerini kesinlikle görememelidir.

Bu kural sistemin temel güvenlik prensibidir.

# 37. YETKİLENDİRME

İlk sürüm: OWNER kullanıcısını destekleyebilir.

Gelecekte: OWNER, ADMIN, TECHNICIAN, ACCOUNTING, VIEWER rolleri eklenmelidir.

Örnek — Teknisyen:
İşleri görebilir, Servis formu doldurabilir, Fotoğraf ekleyebilir.
Ancak: Finansal raporları göremez, Şirket ayarlarını değiştiremez, Kullanıcı silemez.

# 38. GÜVENLİK

Temel güvenlik: HTTPS, Token tabanlı authentication, Secure storage, API rate limiting, Server-side authorization, Input validation, SQL injection koruması, XSS koruması, CSRF uygun katmanlarda, Dosya upload validation, MIME validation, Maksimum dosya boyutu, Audit log, Hassas verilerin güvenli saklanması

# 39. DOSYA GÜVENLİĞİ

Fotoğraf ve belgeler doğrudan public web klasöründe tutulmamalıdır.

Dosyalar `private/company/{company_id}/...` mantığında tutulmalıdır.

Dosyaya erişim: Yetkilendirilmiş API, Signed URL, Permission kontrolü üzerinden yapılmalıdır.

# 40. BACKUP

Sistem düzenli yedekleme desteklemelidir.

Minimum: Günlük database backup, Dosya backup, Backup retention, Restore testi

SaaS aşamasında: Point-in-time recovery, Disaster recovery, Çoklu storage değerlendirilecektir.

# 41. AUDIT LOG

Önemli işlemler kayıt altına alınmalıdır.

Örnek: İbrahim — 20.08.2026 18:42 — Servis: SRV-2026-00142 — İşlem: Servis tamamlandı. — Tutar: 2.350 TL

Kritik işlemler: Belge oluşturma, Belge silme, Tahsilat, Müşteri değişikliği, Yetki değişikliği, Firma ayarı değişikliği

# 42. MOBİL NAVİGASYON

Ana navigasyon sade tutulmalıdır.

Önerilen yapı:

```
┌────────────────────────────┐
│       EKRAN İÇERİĞİ        │
└────────────────────────────┘

 Ana Sayfa | İşler | Müşteriler | Belgeler | Daha Fazla
```

Ancak "Yeni İş" gibi kritik aksiyonlar hızlı erişilebilir olmalıdır.

# 43. MOBİL TASARIM PRENSİPLERİ

Uygulama: Büyük dokunma alanları, Büyük yazılar, Yüksek kontrast, Sade ikonlar, Minimum form alanı, Akıllı varsayılanlar, Otomatik tarih/saat, Otomatik numaralandırma, Açık hata mesajları kullanmalıdır.

Kullanıcı mümkün olduğunca az yazmalıdır.

# 44. FORM TASARIMI

Örneğin yeni iş:

```
Müşteri     [ABC Market]
İş Türü     [Kamera]
Talep       [________________]
Öncelik     [Yüksek]
Tarih       [20 Ağustos]
Saat        [18:00]

[ İŞİ OLUŞTUR ]
```

Gereksiz alanlar ilk ekranda gösterilmemelidir.

İleri detaylar "Daha Fazla" altında açılmalıdır.

# 45. AKILLI NUMARALANDIRMA

Sistem otomatik numara üretmelidir.

Örnek:
Müşteri: CUS-2026-00152
Talep: REQ-2026-00231
Servis: SRV-2026-00142
Teklif: QTE-2026-00081
Proforma: PRO-2026-00054
Tahsilat: PAY-2026-00125

Numaralar şirket bazında yönetilmelidir.

# 46. ARAMA

Global arama desteklenmelidir.

Kullanıcı "ABC" yazdığında: Müşteri, İş, Belge, Servis, Tahsilat sonuçları bulunmalıdır.

# 47. FİLTRELEME

İşlerde: Tarih, Durum, İş türü, Müşteri, Teknisyen, Öncelik filtreleri.

Finansta: Tarih, Gelir/gider, Kategori, Müşteri, Ödeme durumu filtreleri.

# 48. BİLDİRİMLER

Bildirim türleri:

🔔 Yarın 10:00'da ABC Market servisi var.

💰 Mehmet Kaya'dan 3.500 TL tahsilat bekliyor.

📄 XYZ teklifinin süresi yarın doluyor.

🛠️ ABC Market'in bakım zamanı geldi.

# 49. GARANTİ VE BAKIM

V2'de: Her iş için Garanti başlangıç, Garanti bitiş, Garanti süresi, Bakım periyodu tanımlanabilmelidir.

Örneğin: Kamera sistemi 12 ay garantili.

Sistem garanti bitişinden önce bildirim gönderebilir.

# 50. RAPORLAR

V2/V3:

**Finans:** Gelir, Gider, Net, Tahsilat, Borç

**İş:** Tamamlanan işler, İptal işler, Bekleyen işler, İş türleri

**Müşteri:** En çok iş yapılan müşteriler, En yüksek ciro, Borçlu müşteriler, Son servis tarihi

**Kârlılık:** İş bazlı maliyet, Malzeme maliyeti, İşçilik, Yakıt, Net kâr

# 51. AI VİZYONU

AI ilk sürümün gereksinimi değildir.

Ancak mimaride ileride kullanılabilecek şekilde tasarlanmalıdır.

Örnek:

İbrahim konuşur: "ABC markete gittim. Üç kamera çalışmıyordu. İki RJ45 değiştirdim, bir adaptör değiştirdim. Toplam 2.500 lira yaz."

AI: Müşteri: ABC Market — Arıza: 3 kamera çalışmıyor. — Yapılan İş: 2 RJ45 değişimi, 1 adaptör değişimi — Servis Bedeli: 2.500 TL

şeklinde servis kaydı oluşturabilir.

# 52. AI İLE TEKLİF OLUŞTURMA

Kullanıcı: "8 kameralı sistem için teklif hazırla."

AI: Ürünleri önerir, İş kalemlerini oluşturur, Miktarları düzenler, Kullanıcının fiyatlarını baz alır, Teklif taslağı oluşturur

Ancak son fiyat ve belge gönderimi kullanıcı onayına bağlı olmalıdır.

# 53. SAAS VİZYONU

İbrahim'in uygulaması başarılı olursa ürün SaaS'a dönüştürülebilir.

Yeni kullanıcı:

```
TeknikOS'a Hoş Geldiniz

İşletme türünüz:
☑ Elektrik  ☑ Kamera  ☑ Bilgisayar

Firma bilgilerinizi girin.
Logo yükleyin.
IBAN girin.

Hazırsınız.
```

# 54. SAAS TENANCY

Her şirket Company olarak kabul edilir.

Kullanıcılar (Users) şirkete bağlıdır.

Tüm veriler company_id ile izole edilir.

# 55. ABONELİK MODELİ

Gelecekte:

**Free:** 1 kullanıcı, 50 müşteri, Temel işler, Temel belgeler

**Pro:** Sınırsız müşteri, Sınırsız işler, PDF, Finans, Stok, Raporlar

**Business:** Çoklu kullanıcı, Yetkilendirme, Gelişmiş rapor, API, Entegrasyonlar

Bu model ilk MVP'de uygulanmayacaktır.

# 56. İLK SÜRÜMDE YAPILMAYACAKLAR

MVP'yi gereksiz büyütmemek için: Komple muhasebe sistemi, Resmi e-Fatura altyapısı, Maaş sistemi, Tam ERP, Gelişmiş stok, Gelişmiş CRM, WhatsApp Business API, Online ödeme altyapısı, AI, Multi-company yönetimi ilk sürümde zorunlu değildir.

Bunlar roadmap'e bırakılacaktır.

# 57. MVP GELİŞTİRME SIRASI

**Sprint 1:** Flutter projesi, Laravel API, Authentication, Company, User, Database, Temel navigation, Dashboard

**Sprint 2:** Müşteriler, Müşteri profili, Adresler, İşler, Talepler

**Sprint 3:** Servis formu, Fotoğraf, Not, Dijital imza, Servis durumları

**Sprint 4:** Teklif, Proforma, PDF, Belge merkezi

**Sprint 5:** Gelir, Gider, Tahsilat, Finans dashboard

**Sprint 6:** Offline database, Sync engine, Conflict handling, Backup, Error handling

**Sprint 7:** WhatsApp sharing, Bildirimler, Takvim, Harita

**Sprint 8:** Gerçek kullanıcı testleri, Bug fixing, UX iyileştirmeleri, Performance, Release build

# 58. V2 ROADMAP

Stok, Malzeme, Garanti, Bakım, Randevu, Gelişmiş raporlar, Personel, Yetkilendirme, Web panel, Çoklu cihaz, Cloud sync geliştirmeleri

# 59. V3 ROADMAP

SaaS, Abonelik, Multi-tenant, Çoklu şirket, Personel, API, E-posta, SMS, WhatsApp Business, E-Fatura entegrasyonları, Online ödeme

# 60. V4 ROADMAP

AI servis kayıtları, AI teklif oluşturma, AI raporlama, Sesli kullanım, Akıllı fiyat önerileri, Otomatik müşteri takibi, Tahsilat tahmini, İş kârlılık analizi

# 61. TEKNİK MİMARİ

**Mobile — Flutter**
```
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

State management ve kütüphaneler proje başlangıcında güncel ve stabil seçenekler değerlendirilerek kesinleştirilecektir.

# 62. BACKEND

Laravel API:

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

Business logic controller içerisinde dağınık şekilde tutulmamalıdır.

# 63. API PRENSİPLERİ

API: RESTful, Versioned, JSON, Authenticated, Validated, Paginated olmalıdır.

Örnek:
```
/api/v1/auth/login
/api/v1/customers
/api/v1/jobs
/api/v1/service-requests
/api/v1/quotes
/api/v1/proformas
/api/v1/payments
/api/v1/incomes
/api/v1/expenses
```

# 64. API RESPONSE STANDARDI

Başarılı response:
```json
{
  "success": true,
  "data": {},
  "message": null
}
```

Hata:
```json
{
  "success": false,
  "data": null,
  "message": "İşlem gerçekleştirilemedi.",
  "errors": {}
}
```

# 65. PAGINATION

Liste endpointleri pagination desteklemelidir.

Örneğin: `?page=1&per_page=20`

Sunucu gereksiz miktarda veri döndürmemelidir.

# 66. LOCAL DATABASE

Mobil tarafta offline veriler için lokal database kullanılmalıdır.

Önerilen yapıda: customers, jobs, service_requests, quotes, proformas, payments, incomes, expenses, sync_queue tabloları bulunmalıdır.

# 67. SYNC CONFLICT

Aynı kayıt farklı cihazlardan değiştirilirse sistem conflict oluşturmalıdır.

İlk sürüm: server_updated_at, local_updated_at, version alanlarıyla temel conflict detection yapmalıdır.

Çatışmalı kayıt otomatik olarak sessizce ezilmemelidir.

# 68. PERFORMANS

Mobil: Lazy loading, Pagination, Image compression, Thumbnail, Cache, Background sync kullanmalıdır.

Fotoğraflar yüklenmeden önce uygun çözünürlüğe küçültülmelidir.

# 69. LOGGING

Backend: Error logs, Request logs, Queue logs, Audit logs

Mobil: Crash reporting, Sync errors, Network errors

tutmalıdır.

Kullanıcıya teknik stack trace gösterilmemelidir.

# 70. TEST STRATEJİSİ

**Backend:** Unit tests, Feature tests, API tests, Authorization tests

**Flutter:** Unit tests, Widget tests, Integration tests

**Kritik senaryolar:** Müşteri oluşturma, İş oluşturma, Servis tamamlama, PDF oluşturma, Tahsilat, Offline kayıt, Sync, Yetkisiz erişim, Dosya upload

# 71. GERÇEK HAYAT TEST SENARYOSU

Test:
1. İnternet kapatılır.
2. Yeni müşteri oluşturulur.
3. Yeni servis oluşturulur.
4. Fotoğraf çekilir.
5. Servis formu hazırlanır.
6. Müşteri imza atar.
7. Tahsilat girilir.
8. İnternet açılır.
9. Sistem otomatik sync olur.
10. Server'da bütün kayıtlar görünür.
11. PDF oluşturulur.
12. WhatsApp ile paylaşılır.

Bu senaryo başarıyla çalışmadan MVP tamamlanmış kabul edilmemelidir.

# 72. UX TESTİ

Gerçek kullanıcı olarak İbrahim'in aşağıdaki işleri yardım almadan yapabilmesi gerekir:

Müşteri eklemek, Servis oluşturmak, Fotoğraf eklemek, Servisi tamamlamak, PDF göndermek, Tahsilat girmek, Gelir/gider görmek, Eski müşteriyi bulmak

Eğer kullanıcı bir işlem için geliştiriciye ihtiyaç duyuyorsa UX yeterince iyi değildir.

# 73. VERİ SİLME PRENSİBİ

Finansal veya önemli iş kayıtları doğrudan hard delete edilmemelidir.

Örneğin: `deleted_at` kullanılabilir.

Kritik belgelerde silme yerine İPTAL durumu tercih edilmelidir.

# 74. PARA BİRİMİ

MVP Türkiye odaklıdır.

Varsayılan: TRY / ₺ olacaktır.

Ancak database `currency` alanını desteklemelidir.

İleride: USD, EUR, GBP gibi para birimleri eklenebilir.

# 75. VERGİ / KDV

KDV sistemi esnek olmalıdır.

Her kalem için `tax_rate` tutulmalıdır.

Örnek: %0, %1, %10, %20

KDV oranları uygulama içerisinde sabit kodlanmamalıdır.

Kullanıcı/şirket ayarlarından yönetilebilir olmalıdır.

Resmi vergi/muhasebe mevzuatıyla ilgili kararlar ürün geliştirme aşamasında ayrıca doğrulanmalıdır.

# 76. KVKK VE VERİ GİZLİLİĞİ

Sistem müşteri: Ad, Soyad, Telefon, Adres, E-posta gibi kişisel veriler saklayacaktır.

Bu nedenle: Açık ve anlaşılır gizlilik politikası, Veri işleme süreçleri, Yetki kontrolü, Veri silme talepleri, Veri güvenliği, Backup güvenliği tasarlanmalıdır.

# 77. HUKUKİ SINIR

TeknikOS "Muhasebe programı" olarak konumlandırılmak zorunda değildir.

MVP: İşletme ve teknik servis yönetim platformu olarak konumlandırılmalıdır.

Resmi fatura/e-Fatura/e-Arşiv gibi özellikler gerektiğinde ilgili mevzuat ve yetkili entegratör gereksinimleri ayrıca değerlendirilmelidir.

Sistem oluşturduğu servis formu, teklif veya proformayı otomatik olarak "resmi fatura" olarak tanımlamamalıdır.

# 78. ÜRÜNÜN EN ÖNEMLİ ÖZELLİĞİ

TeknikOS'un amacı "Her şeyi yapan dev bir ERP olmak" değildir.

Amaç: Sahada çalışan teknik işletmenin telefonunu işletme merkezine dönüştürmek.

# 79. ANA KULLANICI DENEYİMİ

İbrahim'in uygulamayı açtığında düşünmesi gereken şey: "Bugün ne yapacağım?"

Uygulama bunu cevaplamalıdır.

Örneğin:

```
Bugün 3 işin var.

10:00  ABC Market — Kamera arızası
14:00  Mehmet Kaya — Bilgisayar kurulumu
18:00  XYZ Apartmanı — İnterkom arızası

Bugün tahsil edilmesi beklenen: ₺4.750
```

Bu yaklaşım ürünün merkezinde olmalıdır.

# 80. GELİŞTİRME FELSEFESİ

Kod: Basit, Modüler, Test edilebilir, Dokümante, Güvenli, Ölçeklenebilir olmalıdır.

"Şimdilik böyle yapalım, sonra düzeltiriz" yaklaşımı özellikle veri modeli ve yetkilendirme gibi kritik alanlarda kullanılmamalıdır.

# 81. CURSOR / AI GELİŞTİRME KURALLARI

AI geliştirme ajanı:
- Önce mevcut yapıyı analiz etmelidir.
- Rastgele dosya oluşturmamalıdır.
- Mevcut mimariyi bozmadan geliştirmelidir.
- Database migration kullanmalıdır.
- API contract'larını değiştirmeden önce kontrol etmelidir.
- Güvenlik kontrollerini atlamamalıdır.
- Test yazmadan kritik modülü tamamlanmış saymamalıdır.
- Mock data ile gerçek database akışını karıştırmamalıdır.
- UI'da hardcoded business logic kullanmamalıdır.
- Şirket izolasyonunu hiçbir koşulda bozmamalıdır.
- Finansal değerlerde floating-point para hesaplaması kullanılmamalıdır.
- Para değerleri güvenli decimal/integer minor-unit yaklaşımıyla saklanmalıdır.
- Dosyalar public olarak açılmamalıdır.
- Yetkilendirme sadece frontend'e bırakılmamalıdır.
- Kullanıcıdan gereksiz bilgi istenmemelidir.

# 82. PARA HESAPLAMA KURALI

Para değerleri FLOAT olarak tutulmamalıdır.

Önerilen yaklaşım: `amount_minor`

örneğin: 2500.50 TL → database'de 250050 olarak tutulabilir.

Para işlemleri merkezi bir money/value object katmanından geçirilmelidir.

# 83. BELGE NUMARASI KURALI

Belge numarası client tarafında oluşturulmamalıdır.

Sunucu tarafından transaction-safe şekilde oluşturulmalıdır.

Aynı belge numarası iki kez oluşmamalıdır.

# 84. TRANSACTION KURALI

Aşağıdaki işlemler transaction içinde ele alınmalıdır: Tahsilat oluşturma, Stok hareketi, Belge oluşturma, İş tamamlanması, Finans kaydı

Kısmi başarısızlıkta sistem tutarsız durumda bırakılmamalıdır.

# 85. API AUTHORIZATION

Her endpoint şu katmanlardan geçmelidir:

```
Authentication → Company Context → Authorization → Resource Policy → Action
```

Frontend'deki gizli route kontrolü güvenlik olarak kabul edilmemelidir.

# 86. FOTOĞRAF OPTİMİZASYONU

Mobil akış:

```
Camera → Resize → Compress → Upload Queue → Storage
```

Orijinal fotoğraf her durumda saklanmak zorunda değildir.

# 87. DASHBOARD VERİSİ

Dashboard tek bir dev API response'una bağlanmamalıdır.

İhtiyaca göre summary, today, payments, jobs gibi endpointler kullanılabilir veya optimize edilmiş dashboard endpoint'i oluşturulabilir.

# 88. MVP BAŞARI KRİTERİ

MVP başarılı sayılırsa İbrahim tek başına:

Müşteri oluşturabilir → Talep alabilir → Servis planlayabilir → Servis gerçekleştirebilir → Fotoğraf ekleyebilir → İmza alabilir → Servis formu oluşturabilir → PDF gönderebilir → Tahsilat girebilir → Gelir/gider görebilir

ve bütün süreç için bilgisayara ihtiyaç duymaz.

# 89. GELECEKTEKİ ÜRÜN

TeknikOS'un uzun vadeli hedefi:

Mobil Uygulama + Web Panel + Cloud + SaaS + AI + Entegrasyonlar

olmalıdır.

# 90. SON ÜRÜN VİZYONU

Bir teknik servis sahibi sabah telefonunu açar.

TeknikOS ona:

"Günaydın İbrahim. Bugün 4 işin var. 2 müşteriden toplam ₺7.500 tahsilat bekleniyor. 1 teklif cevap bekliyor. 3 müşterinin bakım zamanı yaklaşıyor."

der.

İbrahim bir bilgisayarın başına geçmek zorunda kalmadan: Müşterilerini yönetir, İşlerini yönetir, Servislerini tamamlar, Belgelerini hazırlar, Tahsilatlarını takip eder, Gelir-giderini görür, Müşteriye profesyonel evrak gönderir.

Ve günün sonunda: "Bugün ne yaptım, ne kazandım, kimden alacağım var ve yarın ne yapacağım?" sorusunun cevabını tek ekranda görebilir.

# 91. PROJEDE ANA HEDEF

TeknikOS: "Teknik servis işletmesinin cebindeki ofisi." olmalıdır.

Bu proje önce İbrahim'in gerçek ihtiyacını çözmelidir.

İbrahim'in kullanımından elde edilen gerçek geri bildirimlerle geliştirilmeli ve ancak ürün-market uyumu görüldükten sonra genel SaaS ürününe dönüştürülmelidir.

# 92. İLK GELİŞTİRME EMRİ

Projeye başlanırken geliştirme ajanı aşağıdaki sırayı takip etmelidir:

PHASE 1 — Project Architecture
PHASE 2 — Database Schema
PHASE 3 — Laravel API Foundation
PHASE 4 — Flutter Foundation
PHASE 5 — Authentication
PHASE 6 — Company Profile
PHASE 7 — Customer Management
PHASE 8 — Service Request
PHASE 9 — Job / Service Management
PHASE 10 — Service Form
PHASE 11 — Photo + Signature
PHASE 12 — Quote / Proforma
PHASE 13 — PDF Engine
PHASE 14 — Income / Expense
PHASE 15 — Payments
PHASE 16 — Offline Engine
PHASE 17 — Synchronization
PHASE 18 — Notifications
PHASE 19 — WhatsApp Sharing
PHASE 20 — Real User Testing

Her phase tamamlanmadan bir sonraki faza geçilmemelidir.

# 93. DEFINITION OF DONE

Bir özellik "tamamlandı" sayılabilmesi için: Backend hazır, Database migration hazır, API hazır, Authorization hazır, Mobile UI hazır, Loading state hazır, Empty state hazır, Error state hazır, Validation hazır, Offline davranış belirlenmiş, Testler yazılmış, Gerçek cihazda test edilmiş, Dokümantasyon güncellenmiş olmalıdır.

# 94. SONUÇ

TeknikOS basit bir "Müşteri kayıt uygulaması" değildir.

Temel amacı: Müşteri → Talep → İş → Servis → Belge → Tahsilat → Finans → Geçmiş zincirini tek sistemde birleştirmektir.

İlk kullanıcı İbrahim olacaktır.

İlk hedef İbrahim'in günlük işlerini tamamen mobil hale getirmektir.

İkinci hedef gerçek kullanım verileriyle ürünü geliştirmektir.

Üçüncü hedef ürünü teknik servis ve saha işletmeleri için SaaS'a dönüştürmektir.

Uzun vadeli hedef: Türkiye'deki küçük ve orta ölçekli saha hizmet işletmelerinin günlük operasyonlarını yönetebileceği modern, mobil-first bir işletme platformu oluşturmak.

## PROJECT STATUS

```
Project:          TeknikOS
Stage:             PLANNING
MVP:               NOT STARTED
Primary User:      İbrahim
Platform:          Android
Mobile:            Flutter
Backend:           Laravel
Database:          PostgreSQL
Architecture:      Offline-First
Business Model:    Single Business → SaaS
Priority:          HIGH
Next Step:         Architecture + Database + MVP Implementation
```

## FINAL PRODUCT PRINCIPLE

Karmaşık bir sistemi kullanıcıya karmaşık hissettirmeden sun.

İbrahim'in telefonunu işletmesinin merkezine dönüştür.
