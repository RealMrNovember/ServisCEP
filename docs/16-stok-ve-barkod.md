# 16 — Stok ve Barkod Modülü

> Bu doküman, geliştirme sürecinde eklenen bir gereksinimdir (bkz. [ROADMAP.md § Ek Gereksinimler](../ROADMAP.md#ek-gereksinimler-sonradan-eklenen)). Orijinal spesifikasyon stoku MVP'de opsiyonel/basit tutuyordu (§25-26); bu doküman, teklif/proforma kalemlerinin stoktan seçilebilmesi ve barkod okuma gereksinimiyle kapsamı genişletir.

## Neden

Kullanıcı, teklif/proforma hazırlarken her kalemi (ürün adı, birim fiyat, KDV vb.) **sıfırdan elle yazmak zorunda kalmamalı** — sık kullanılan ürünler (RJ45, kablo, kamera modelleri vb.) bir katalogdan **seçilebilmeli**. Bu hem hız hem tutarlılık (aynı ürün her seferinde farklı yazılmasın) sağlar. Ayrıca elde ne kadar stok kaldığının görülebilmesi, sahada "bu parça bende var mı?" sorusuna anında cevap verir.

## Kapsam Kararları

1. **Stok, teklif/proforma/servis formu kalemlerinin birincil kaynağıdır** — kullanıcı kalem eklerken önce ürün kataloğundan arayıp seçer; katalogda yoksa serbest metin girmeye devam edebilir (stok zorunlu değil, ama önerilir).
2. **Stok durumu badge'i yalnızca uygulama içi arayüzdedir, belgelerde (PDF) ASLA görünmez.** Teklif/proforma/fatura gibi müşteriye giden belgeler yalnızca ürün adı, miktar, fiyat gösterir — "stokta yok" gibi iç bilgi müşteriyle paylaşılmaz.
3. **Barkod okuma iki aşamalıdır:** (a) telefon kamerasıyla barkod tara → (b) önce **yerel stokta** bu barkod var mı diye bak → yoksa **global bir barkod veri kaynağından** (bkz. §4) otomatik ürün bilgisi çekmeyi dene → o da yoksa kullanıcı **manuel** ürün formunu doldurur (barkod önceden dolu gelir).

## 1. Ürün / Stok Veri Modeli

Orijinal `products` şeması (bkz. [04 — Finans ve Stok § Stok Modülü](04-finans-ve-stok.md#4-stok-modülü)) şu alanlarla genişletilir:

| Alan | Açıklama |
|---|---|
| `id` | |
| `companyId` | Şirket izolasyonu |
| `barcode` | Taranan barkod (EAN-13/UPC-A vb.), nullable — her ürünün barkodu olmak zorunda değil |
| `sku` | İç stok kodu (opsiyonel, barkoddan bağımsız) |
| `name` | Ürün adı |
| `brand`, `model` | |
| `category` | |
| `unit` | adet / metre / kutu vb. |
| `purchasePriceMinor`, `salePriceMinor` | Para kuralı — minor-unit (bkz. [04 § Para Hesaplama Kuralı](04-finans-ve-stok.md#para-hesaplama-kuralı-kritik--teknik-zorunluluk)) |
| `currentStock` | Mevcut miktar |
| `minStock` | Minimum stok uyarı eşiği |
| `source` | `MANUAL` / `GLOBAL_LOOKUP` — ürün nasıl oluşturuldu (izlenebilirlik için) |

Stok hareketleri (`stock_movements`) — [26 § Malzeme Kullanımı](04-finans-ve-stok.md#5-malzeme-kullanımı) ile aynı ilke: her azalış/artış bir işe (job) veya manuel düzeltmeye bağlı, immutable bir hareket kaydı olarak tutulur (cari hesap ile aynı felsefe, bkz. [15](15-cari-hesap.md)).

## 2. Stok Durumu Badge'i (Yalnızca Uygulama İçi)

Ürün, herhangi bir kalem seçici listesinde gösterilirken:

| Durum | Görsel | Koşul |
|---|---|---|
| Stokta var | Yeşil badge — "Stokta: N adet" | `currentStock > 0` |
| Stok azalıyor | Turuncu badge — "Az kaldı: N" | `0 < currentStock <= minStock` |
| Stokta yok | Kırmızı badge — "Stokta yok" | `currentStock <= 0` |

> ⚠️ **Kural:** Bu badge yalnızca ürün seçici / stok listesi ekranlarında gösterilir. Teklif, proforma, servis formu gibi **PDF/belge çıktılarında hiçbir stok durumu bilgisi yer almaz** — bkz. [03 § PDF Motoru](03-servis-ve-belge-yonetimi.md#9-pdf-motoru).

## 3. Teklif / Proforma Kalem Seçimi

Kalem ekleme akışı:

```
Kalem Ekle
    ↓
Stoktan Ara (isim/barkod)  ──veya──  Serbest Metin Gir
    ↓                                       ↓
Ürün seçilir → ad/birim/fiyat          Kullanıcı manuel
otomatik dolar, miktar girilir         doldurur (stoksuz kalem)
    ↓                                       ↓
              Kalem listeye eklenir
```

Ürün seçilerek eklenen bir kalem, teklif/proforma **onaylandığında** (`KABUL_EDILDİ`/tamamlanan servis) stoktan düşürülebilir — bu davranış [11 § Transaction Kuralı](07-api-ve-veritabani.md#6-transaction-kuralı) kapsamına stok hareketi olarak zaten dahildi, burada somutlaşıyor.

## 4. Barkod Okuma Akışı

```
Kamera ile barkod tara
        ↓
Yerel stokta bu barkod var mı?
        │
   ┌────┴────┐
  Evet       Hayır
   │           │
Ürünü aç   Global barkod veri kaynağından sorgula
           (ör. UPC/EAN lookup servisi)
                │
           ┌────┴────┐
          Bulundu   Bulunamadı
           │           │
    Bilgiler ön-    Manuel ürün formu
    doldurulur,      açılır (barkod
    kullanıcı        alanı dolu gelir)
    onaylar/düzenler
```

- **Kamera/tarama:** `mobile_scanner` (veya dengi) paketiyle, cihaz kamerası üzerinden EAN/UPC/QR okuma.
- **Global barkod veri kaynağı:** Belirli bir sağlayıcı (ör. UPCitemdb, Barcode Lookup, veya Türkiye'ye uygun bir alternatif) **implementasyon aşamasında** değerlendirilip seçilecektir — dış servise bağımlılık olduğu için API anahtarı/ücretlendirme koşulları netleşmeden burada bir sağlayıcıya kesin taahhüt verilmemiştir. Sorgu, cihaz internete bağlıyken çalışır; **offline'da yerel stok araması her zaman çalışmaya devam eder** (bkz. [08 — Offline-First](08-offline-first-ve-senkronizasyon.md)) — yalnızca "hiç bilinmeyen barkod + internet yok" durumunda kullanıcı manuel girişe yönlendirilir.
- **Manuel ekleme:** Global sorgu sonuçsuz kalırsa veya kullanıcı internetsizse, tarama sonucundaki barkod numarası formda hazır gelir, geri kalan alanlar (ad, fiyat, stok) elle girilir.

## Faz Sıralaması (Bugünkü Plana Eklenme)

Bu modül, [ROADMAP.md § BUGÜN — Mobil Tamamlama Planı](../ROADMAP.md#bugün--mobil-tamamlama-planı-2026-08-18) içine **M8** olarak eklenmiştir (Teklif & Proforma'dan önce, çünkü teklif kalem seçici stok katalogana bağımlıdır). Sonraki M numaraları buna göre kaymıştır — güncel sıra için ROADMAP.md'ye bakın.
