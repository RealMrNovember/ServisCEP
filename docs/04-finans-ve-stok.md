# 04 — Finans ve Stok

> Kaynak: orijinal spesifikasyon §22–§26, §50, §74–§75, §82.

## 1. Gelir Modülü

Gelirler manuel olarak veya bir işle (job) ilişkilendirilerek oluşturulabilir.

**Alanlar:** Tarih · Açıklama · Müşteri · İş · Kategori · Tutar · Ödeme yöntemi · Not

**Gelir Kategorileri:** Servis · Malzeme · Montaj · Bakım · Danışmanlık · Diğer

## 2. Gider Modülü

**Alanlar:** Tarih · Açıklama · Kategori · Tutar · Firma · Fiş/fatura fotoğrafı · Ödeme yöntemi · Not

**Gider Kategorileri:** Malzeme · Yakıt · Araç · Kargo · Telefon · İnternet · Ekipman · Ofis · Personel · Diğer

## 3. Finans Dashboard

Aylık özet görünümü ana metriktir:

```
Gelir       ₺82.450
Gider       ₺31.250
────────────────────
Net         ₺51.200
```

### Ek Raporlar

Günlük gelir · Haftalık gelir · Aylık gelir · Yıllık gelir · Gider dağılımı · Tahsilat durumu · Müşteri bazlı ciro · İş türü bazlı ciro · Kârlılık

> Bu raporlar V2/V3 kapsamında genişletilir — ayrıntılı liste için bkz. [ROADMAP.md](../ROADMAP.md). Genişletilmiş rapor seti:
>
> - **Finans:** Gelir, Gider, Net, Tahsilat, Borç
> - **İş:** Tamamlanan işler, İptal işler, Bekleyen işler, İş türleri
> - **Müşteri:** En çok iş yapılan müşteriler, En yüksek ciro, Borçlu müşteriler, Son servis tarihi
> - **Kârlılık:** İş bazlı maliyet, Malzeme maliyeti, İşçilik, Yakıt, Net kâr

## 4. Stok Modülü

**MVP'de zorunlu bir modül değildir**, ancak veri modeli en baştan itibaren stok desteğine uygun tasarlanmalıdır (bkz. [12 — MVP Kapsamı](12-mvp-kapsami.md)).

### Ürün Alanları

SKU · Barkod · Ürün adı · Marka · Model · Kategori · Birim · Alış fiyatı · Satış fiyatı · Mevcut stok · Minimum stok

### Örnek Stok Kalemleri

| Ürün | Miktar |
|---|---|
| RJ45 Konnektör | 142 adet |
| Cat6 Kablo | 315 metre |
| IP Kamera 5MP | 8 adet |

## 5. Malzeme Kullanımı

Bir servis sırasında kullanılan malzemeler (ör. `2 x RJ45`, `1 x 12V Adaptör`, `10 metre Cat6`) stoktan düşülebilmelidir. Bu işlem her zaman ilgili **servis kaydıyla ilişkilendirilmelidir** — stok hareketi sahipsiz olamaz.

> Stok düşümü, transaction içinde ele alınması gereken kritik işlemlerden biridir. Bkz. [11 — Geliştirme Prensipleri § Transaction Kuralı](11-gelistirme-prensipleri.md).

## 6. Para Birimi

- MVP **Türkiye odaklıdır**, varsayılan para birimi **TRY / ₺**.
- Ancak veritabanı şeması en baştan bir `currency` alanı desteklemelidir.
- İleride USD, EUR, GBP gibi para birimleri eklenebilir (SaaS/uluslararası genişleme için).

## 7. Vergi / KDV

KDV sistemi **esnek** olmalıdır:

- Her kalem için ayrı `tax_rate` tutulmalıdır (`%0`, `%1`, `%10`, `%20` gibi).
- KDV oranları **uygulama içinde sabit kodlanmamalıdır** — kullanıcı/şirket ayarlarından yönetilebilir olmalıdır.
- Resmi vergi/muhasebe mevzuatına ilişkin kararlar, ürün geliştirme aşamasında ayrıca doğrulanmalıdır (bu doküman muhasebe/vergi danışmanlığı yerine geçmez).

## Para Hesaplama Kuralı (Kritik — Teknik Zorunluluk)

> ⚠️ Para değerleri **hiçbir koşulda `FLOAT`/`double` olarak tutulamaz.**

**Önerilen yaklaşım:** `amount_minor` — para, en küçük birimin (kuruş) tam sayı katı olarak saklanır.

```
Örnek:  2.500,50 TL  →  veritabanında  250050  (integer, minor unit)
```

Tüm para işlemleri (toplama, KDV hesabı, iskonto, yuvarlama), merkezi bir **money / value object** katmanından geçirilmelidir — dağınık aritmetik işlemler yasaktır. Bu kural özellikle Servis Formu, Proforma, Teklif, Fatura ve Tahsilat modüllerinin tümünde geçerlidir.
