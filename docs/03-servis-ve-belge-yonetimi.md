# 03 — Servis ve Belge Yönetimi

> Kaynak: orijinal spesifikasyon §14–§21, §31–§32, §45, §83.

Bu doküman, bir işin sahada tamamlanmasından profesyonel belgelerin (teklif, proforma, fatura) üretilmesine kadar olan tüm belge yaşam döngüsünü kapsar.

## 1. Servis Formu

Servis formu, sistemin **en önemli belgelerinden biridir** — sahada yapılan işin hukuki ve operasyonel kaydıdır.

### Örnek Servis Formu

```
SERVİS FORMU

Servis No:        SRV-2026-00142
Müşteri:          ABC Market
Servis Tarihi:    20.08.2026

Arıza / Talep:    3 kamera görüntü vermiyor.
Tespit:           PoE bağlantısında problem bulundu.

Yapılan İşlemler:
  - PoE switch kontrol edildi.
  - RJ45 bağlantıları yenilendi.
  - Kamera adaptörü değiştirildi.

Kullanılan Malzemeler:
  2 x RJ45
  1 x 12V Adaptör

Servis Ücreti:     1.500 TL
Malzeme:             850 TL
─────────────────────────────
Toplam:            2.350 TL

Müşteri imzası     Teknisyen imzası     Tarih
```

## 2. Dijital İmza

- Müşteri, telefon ekranında parmakla (touch) imza atabilmelidir.
- İmza servis kaydına bağlanır ve PDF'e otomatik eklenir.
- İmza, **değiştirilemez kayıt** olarak saklanmalıdır (immutable — oluşturulduktan sonra üzerine yazılamaz).

> ⚠️ **Hukuki uyarı:** İmzanın hukuki niteliği konusunda sistem, bunun **resmi elektronik imza (e-imza/5070 sayılı kanun kapsamındaki nitelikli elektronik imza) yerine geçtiği izlenimini vermemelidir.** Pazarlama ve arayüz metinlerinde bu ayrım net olmalıdır.

## 3. Fotoğraf Sistemi

Her iş kaydına fotoğraf eklenebilmelidir.

### Fotoğraf Kategorileri

- İş Öncesi
- Arıza
- Montaj
- İş Sonrası
- Malzeme
- Diğer

Fotoğraflar her zaman bir iş kaydıyla ilişkilendirilmelidir — kategorisiz/sahipsiz fotoğraf yüklemesi desteklenmez. Fotoğraf işleme akışı için bkz. [06 — Teknik Mimari § Fotoğraf Optimizasyonu](06-teknik-mimari.md#fotoğraf-optimizasyonu).

## 4. Proforma Modülü

### Oluşturma Akışı

```
Yeni Proforma → Müşteri → Kalemler → Miktar → Birim Fiyat
             → KDV → İskonto → Toplam → Notlar → PDF
```

### Alanlar

Belge numarası · Tarih · Geçerlilik tarihi · Firma bilgileri · Müşteri bilgileri · Ürün/hizmet · Miktar · Birim · Birim fiyat · İskonto · KDV · Ara toplam · Genel toplam · IBAN · Açıklama · Ödeme şartları

## 5. Teklif Modülü

Teklif, **proformadan ayrı bir belge tipi** olarak tasarlanmalıdır — aynı veri modelini paylaşsa da farklı bir belge yaşam döngüsüne (durum makinesine) sahiptir.

### Örnek

```
TEKLİF

8 Adet IP Kamera
1 Adet NVR
1 Adet PoE Switch
2 TB HDD
Cat6 Kablo
Montaj ve İşçilik
─────────────────────
TOPLAM: 56.500 TL
```

### Teklif Durumları

```
TASLAK → GÖNDERİLDİ → BEKLEMEDE → KABUL EDİLDİ
                              ↘ REDDEDİLDİ
                              ↘ SÜRESİ DOLDU
```

## 6. Belge Merkezi

Tüm belgeler tek noktadan erişilebilir olmalıdır.

```
Belgeler
├── Proformalar
├── Teklifler
├── Servis Formları
├── Faturalar
├── Tahsilat Belgeleri
├── Garanti Belgeleri
└── Diğer
```

**Filtreler:** Müşteri · Tarih · Belge tipi · Durum · Tutar

## 7. Fatura Yaklaşımı (MVP Kapsamı)

> **MVP'de resmi e-Fatura sistemi kurulmayacaktır.**

İlk aşamada desteklenen basit fatura kaydı:

- Fatura numarası
- Fatura tarihi
- Müşteri
- Tutar
- KDV
- Ödeme durumu
- PDF
- Dosya arşivi

Resmi e-Fatura / e-Arşiv entegrasyonu, ayrı bir faz olarak roadmap'e bırakılmıştır (bkz. [ROADMAP.md](../ROADMAP.md)). Entegrasyon gerektiğinde ilgili mevzuat ve yetkili e-fatura entegratörü gereksinimleri ayrıca değerlendirilmelidir.

> Bu MVP kısıtının hukuki gerekçesi için bkz. [09 — Güvenlik ve Yetkilendirme § Hukuki Sınır](09-guvenlik-ve-yetkilendirme.md#hukuki-sınır).

## 8. Tahsilat Modülü

Her işin ödeme durumu ayrı takip edilir.

### Durumlar

`ÖDENMEDİ` · `KISMİ ÖDENDİ` · `ÖDENDİ`

### Örnek

```
İş Tutarı:        8.500 TL
Tahsil Edildi:     5.000 TL
Kalan:             3.500 TL
```

## 9. PDF Motoru

Üretilen tüm belgeler profesyonel ve kurumsal görünmelidir. Her PDF şu alanları desteklemelidir:

Firma logosu · Firma bilgileri · Müşteri bilgileri · Belge numarası · Tarih · Ürün/hizmet tablosu · KDV · Toplam · IBAN · Açıklama · İmza

Tasarım ilkesi: **sade, modern, kurumsal.**

## 10. Belge Şablonu Sistemi (İleri Aşama)

İleride kullanıcı, birden fazla hazır şablon arasından seçim yapabilmelidir:

| Şablon | Stil |
|---|---|
| Şablon A | Minimal |
| Şablon B | Kurumsal |
| Şablon C | Teknik Servis |
| Şablon D | Klasik |

Firma logosu ve marka renkleri, seçilen şablona otomatik uygulanabilmelidir.

## Akıllı Numaralandırma

Sistem, tüm belge tiplerinde otomatik ve **öngörülebilir** numara üretmelidir:

| Belge Tipi | Format Örneği |
|---|---|
| Müşteri | `CUS-2026-00152` |
| Talep | `REQ-2026-00231` |
| Servis | `SRV-2026-00142` |
| Teklif | `QTE-2026-00081` |
| Proforma | `PRO-2026-00054` |
| Tahsilat | `PAY-2026-00125` |

Numaralar **şirket bazında** yönetilir (her `company_id` kendi sayaç serisine sahiptir).

> ⚠️ **Kritik kural:** Belge numarası **client (mobil uygulama) tarafında üretilemez.** Sunucu tarafında, transaction-safe bir sayaç mekanizmasıyla üretilmelidir — aksi halde offline senaryoda çakışan numaralar oluşabilir. Aynı belge numarası hiçbir koşulda iki kez üretilemez. Detaylar için bkz. [11 — Geliştirme Prensipleri § Transaction Kuralı](11-gelistirme-prensipleri.md).
