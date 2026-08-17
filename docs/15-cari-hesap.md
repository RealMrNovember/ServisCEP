# 15 — Cari Hesap (Müşteri Ekstresi)

> Bu doküman, geliştirme sürecinde eklenen bir gereksinimdir (bkz. [ROADMAP.md § Ek Gereksinimler](../ROADMAP.md#ek-gereksinimler-sonradan-eklenen)). Orijinal spesifikasyon yalnızca müşteri bazlı **özet** finans rakamları öngörüyordu (§10 — Toplam iş tutarı, Tahsil edilen, Bekleyen, Toplam borç). Bu doküman, bunu gerçek bir **cari hesap** (kronolojik borç/alacak hareketleri + bakiye) olarak formelleştirir.

## Kapsam Kararı

- **Yalnızca müşteri carisi.** Tedarikçi/firma cari hesabı MVP kapsamında **değildir** — [04 — Finans ve Stok § Gider Modülü](04-finans-ve-stok.md#2-gider-modülü) içindeki serbest metin `Firma` alanı MVP için yeterli kabul edilmiştir. Tedarikçi cari hesabı, ileride ayrı bir `suppliers` varlığı olarak V2/V3 kapsamında değerlendirilebilir.
- **Tam ekstre MVP'dedir** — yalnızca özet bakiye değil, kronolojik hareket listesi + PDF ekstre çıktısı MVP'nin bir parçasıdır (özet rakamlara ek olarak, onları besleyen kaynak).

## Neden Ayrı Bir Cari Hesap Tablosu?

[02 — İş Alanı ve Veri Modeli § Müşteri Profili](02-is-alani-ve-veri-modeli.md#1-müşteri-customer) içindeki "Finans" sekmesi (Toplam iş tutarı, Tahsil edilen, Bekleyen, Toplam borç) yalnızca **özet** rakamlardır — geçmiş hareketleri gösteremez, denetlenebilir/izlenebilir değildir, PDF ekstre üretilemez. Bir işletme sahibinin *"bu bakiye nereden geldi?"* sorusuna cevap verebilmesi için hareketlerin **kronolojik ve değiştirilemez** bir kaydı gerekir — tıpkı [09 — Güvenlik ve Yetkilendirme § Audit Log](09-guvenlik-ve-yetkilendirme.md#5-audit-log) prensibiyle uyumlu şekilde.

## Cari Hareket Türleri

| Tür | Ne zaman oluşur | Bakiyeye etkisi |
|---|---|---|
| **BORÇ** | İş tamamlanıp gerçek fiyat girildiğinde | Müşteri borcu artar |
| **ALACAK** | Tahsilat kaydedildiğinde (bkz. [03 § Tahsilat Modülü](03-servis-ve-belge-yonetimi.md#8-tahsilat-modülü)) | Müşteri borcu azalır |
| **Manuel Düzeltme** | Açılış bakiyesi girişi, hata düzeltmesi | Borç veya alacak yönünde, **gerekçe alanı zorunlu** |

> ⚠️ **Mükerrer kayıt uyarısı:** Fatura kesilmesi ([03 § Fatura Yaklaşımı](03-servis-ve-belge-yonetimi.md#7-fatura-yaklaşımı-mvp-kapsamı)) **ayrıca borç kaydı oluşturmaz** — fatura, işin tamamlanmasıyla zaten oluşmuş borcun resmi belgeleşmesidir. Borç kaynağı tekildir: **iş (job) tamamlanması.**

## Veri Modeli

Yeni tablo: `customer_ledger_entries`

| Alan | Açıklama |
|---|---|
| `id` | |
| `company_id` | Şirket izolasyonu (bkz. [07 § Şirket Bazlı Veri Ayrımı](07-api-ve-veritabani.md#5-şirket-bazlı-veri-ayrımı-multi-tenancy)) |
| `customer_id` | İlişkili müşteri |
| `entry_date` | Hareket tarihi |
| `type` | `DEBIT` (borç) / `CREDIT` (alacak) |
| `amount_minor` | Tutar — **integer, minor-unit** (bkz. [04 § Para Hesaplama Kuralı](04-finans-ve-stok.md#para-hesaplama-kuralı-kritik--teknik-zorunluluk)) |
| `reference_type` | `job` / `payment` / `manual_adjustment` / `opening_balance` |
| `reference_id` | İlgili kaydın id'si (nullable — manuel düzeltmede boş olabilir) |
| `description` | Kısa açıklama (manuel düzeltmede zorunlu) |
| `created_by` | Kaydı oluşturan kullanıcı |
| `created_at` | |

> Bu tablo, [07 — API ve Veritabanı § Veritabanı Ana Modeli](07-api-ve-veritabani.md#4-veritabanı-ana-modeli) içindeki **Finans** grubuna eklenir (`payments`, `income`, `expenses` ile birlikte).

## Bakiye Hesaplama

- **Kaynak doğruluk (source of truth):** Bir müşterinin bakiyesi, o müşteriye ait tüm `customer_ledger_entries` kayıtlarının toplamıdır (`SUM(DEBIT) - SUM(CREDIT)`).
- Müşteri profilindeki "Toplam borç" özet alanı, bu tablodan **türetilir**. Performans için önbelleğe alınabilir (`customers.cached_balance_minor` gibi), ancak önbellek **her zaman ledger'dan yeniden hesaplanabilir** olmalı ve her yeni ledger kaydında **aynı transaction içinde** güncellenmelidir (bkz. [07 § Transaction Kuralı](07-api-ve-veritabani.md#6-transaction-kuralı) — bu kural artık ledger kayıtlarını da kapsar).
- Ledger kayıtları **immutable**'dır — düzeltme, var olan kaydı değiştirerek değil, yeni bir "Manuel Düzeltme" kaydı ekleyerek yapılır (bkz. [09 § Veri Silme Prensibi](09-guvenlik-ve-yetkilendirme.md#veri-silme-prensibi) ile aynı felsefe).

## Otomatik Kayıt Oluşturma

```
İş tamamlandı + gerçek fiyat girildi  ──►  BORÇ kaydı (reference_type=job)
Tahsilat kaydedildi                    ──►  ALACAK kaydı (reference_type=payment)
Kullanıcı manuel düzeltme girdi        ──►  BORÇ veya ALACAK (reference_type=manual_adjustment)
```

Bu otomatik oluşturma, ilgili işlemlerle (iş tamamlama, tahsilat kaydı) **aynı transaction içinde** yapılmalıdır — kısmi başarısızlıkta (ör. tahsilat kaydedildi ama ledger güncellenmedi) sistem tutarsız bırakılamaz.

## Cari Hesap Ekstresi (PDF)

[03 — Servis ve Belge Yönetimi § Belge Merkezi](03-servis-ve-belge-yonetimi.md#6-belge-merkezi) içine yeni bir belge tipi olarak eklenir: **Cari Hesap Ekstresi**.

İçerik:
- Tarih aralığı seçimi (varsayılan: tüm zamanlar)
- Dönem başı bakiye
- Kronolojik hareket listesi: tarih, açıklama, borç, alacak, hareket sonrası bakiye
- Dönem sonu bakiye
- [03 § PDF Motoru](03-servis-ve-belge-yonetimi.md#9-pdf-motoru) ile aynı kurumsal PDF standardı (firma logosu, bilgileri vb.)

## Müşteri Profili Entegrasyonu

[02 — İş Alanı ve Veri Modeli § Müşteri Profili](02-is-alani-ve-veri-modeli.md#1-müşteri-customer) içindeki "Finans" sekmesi güncellenir:

- Güncel bakiye (ledger'dan türetilmiş, gerçek zamanlı)
- **"Ekstre Görüntüle / PDF İndir"** aksiyonu

## API

```
GET /api/v1/customers/{id}/ledger              → kronolojik hareket listesi (paginated)
GET /api/v1/customers/{id}/ledger/statement     → PDF ekstre üretimi
POST /api/v1/customers/{id}/ledger/adjustments  → manuel düzeltme (gerekçe zorunlu, yetki kontrolü sıkı)
```

> Manuel düzeltme, hassas bir işlemdir — [09 § Yetkilendirme](09-guvenlik-ve-yetkilendirme.md#1-yetkilendirme-roller) kapsamında `OWNER` (ve ileride `ACCOUNTING`) dışındaki roller bu işlemi yapamamalıdır, ve [09 § Audit Log](09-guvenlik-ve-yetkilendirme.md#5-audit-log) kapsamına dahil edilmelidir.

## Kapsam Dışı (MVP)

- Tedarikçi/firma cari hesabı (bkz. yukarıdaki Kapsam Kararı)
- Çoklu para birimi cari hesabı (mevcut `currency` alanı desteklenir ama cari hesap MVP'de tek para birimi varsayar — bkz. [04 § Para Birimi](04-finans-ve-stok.md#6-para-birimi))
