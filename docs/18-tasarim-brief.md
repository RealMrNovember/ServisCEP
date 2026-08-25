# TeknikCEP — Tasarım Brief'i

> Bu dosya, arayüz tasarımı için dışarıdan destek alırken tek başına
> yeterli olacak şekilde yazılmıştır. Başka hiçbir dosyaya bakmaya gerek
> kalmadan okunabilir.

---

## 1. Ürün nedir

TeknikCEP, **saha teknik servis işletmeleri** için mobil bir işletme
yönetim uygulamasıdır. Elektrikçiler, kamera/güvenlik sistemi kurulumcuları,
bilgisayar teknisyenleri gibi "müşterinin yerine gidip iş yapan" küçük
işletmeler kullanır.

Uygulama şunları yapar: müşteri kaydı tutar, iş/randevu planlar, teklif ve
proforma belgesi üretir (PDF), gelir-gider ve cari hesap takip eder, stok
tutar.

**Türkiye pazarı, Türkçe arayüz.** Şu an Android'de kapalı testte.

## 2. Kullanıcı ve kullanım koşulları — tasarımın asıl belirleyicisi

Bu bölüm renk seçiminden daha önemlidir. Kullanıcı:

- **Sahada, ayakta, tek elle** kullanır. Diğer eli alet, kablo veya
  merdivendedir.
- **Güneş altında** ekrana bakar. Düşük kontrast okunmaz.
- **Eldivenli veya kirli parmakla** dokunur. Küçük dokunma hedefleri işe
  yaramaz — minimum 48×48 dp.
- **Aceledir.** Müşteri karşısında beklerken uygulamayla uğraşamaz.
- **Teknoloji meraklısı değildir.** 45-55 yaş aralığı yaygın. Simge
  tahmin etmez, yazı okur.
- **İnterneti kopuktur.** Bodrum katı, asansör boşluğu, kırsal. Uygulama
  offline-first: her şey önce cihaza yazılır, bağlantı gelince sunucuya
  gider.

Bundan çıkan tasarım kuralları:
- Büyük dokunma alanları, geniş boşluk, yüksek kontrast
- Simgeye değil **yazıya** güven; simge yalnızca yazıya eşlik eder
- Ana eylemler ekranın **alt yarısında** (tek elle erişilebilir bölge)
- Durum belirsizliği bırakma: "kaydedildi mi, gitti mi" her zaman görünsün

## 3. Teknik kısıtlar — çizilen şeyin uygulanabilir olması için

Uygulama **Flutter** ile yazılmıştır ve **Material 3** kullanır. Tasarım
bunun içinde kalmalı:

- **Yapılabilir:** özel renk paleti, tipografi ölçeği, kart/kenarlık/gölge
  düzenleri, özel boşluk sistemi, alt sayfalar (bottom sheet), segment
  düğmeleri, çip'ler, özel boş-durum ekranları, özel ikon seti (Material
  Icons dışına çıkılabilir ama SVG/font olarak sağlanmalı).
- **Zor / maliyetli:** karmaşık serbest-form animasyonlar, cam efekti
  (blur) yoğun kullanımı, özel fizik motorları, 3B öğeler.
- **Yapılamaz / istenmiyor:** platform davranışını bozan desenler (Android
  geri tuşu, sistem klavyesi), iOS'a özgü öğelerin Android'e taşınması.

**Açık ve koyu tema ZORUNLU.** Kullanıcıların çoğu telefonu koyu temada
kullanıyor. Her renk için iki değer verilmelidir.

## 4. Mevcut tasarım sistemi (kodda halihazırda tanımlı)

Yeni tasarım bunun yerine geçecekse, karşılıkları verilmelidir.

### Marka renkleri

| Rol | Hex |
|---|---|
| **Aksan (birincil)** | `#3B82F6` |
| Koyu zemin | `#131316` |
| İkincil yüzey / bezel | `#3F3F46` |
| Açık yüzey / ekran | `#FAFAFA` |
| Başarı | `#16A34A` |
| Uyarı | `#F59E0B` |
| Tehlike | `#DC2626` |

Açık temada yüzey `#FBFCFD`, koyu temada `#121316`.

### Ölçüler

Boşluk skalası: `4, 8, 12, 16, 20, 28` (xs → xxl). Ekran kenar boşluğu
yatayda **20**.

Köşe yarıçapı: `10` (küçük), `14` (form alanı), `18` (kart), `24` (diyalog),
`999` (rozet/çip).

Diğer sabitler: birincil buton yüksekliği **52**, ikincil **50**, alt
gezinme çubuğu **68**.

### Mevcut ortak bileşenler

`SectionHeader` (bölüm başlığı + alt açıklama), `AppCard` (kenarlıklı kart,
"accent" varyantı var), `StatusPill` (durum rozeti), `AppEmptyState` (boş
durum), `InfoRowTile` (etiket-değer satırı).

## 5. Ekran envanteri

Toplam **34 ekran**. Alt gezinme 5 sekmeli:

**Ana Sayfa · İşler · Müşteriler · Belgeler · Daha Fazla**

### Sekme ekranları
| Ekran | İçerik |
|---|---|
| Ana Sayfa (dashboard) | Günün işleri, hızlı eylemler, abonelik/deneme uyarısı |
| İşler | İş listesi + durum filtreleri, servis talepleri sekmesi |
| Müşteriler | Müşteri listesi, arama |
| Belgeler | Teklif ve proforma listesi |
| Daha Fazla | Takvim, Finans, Stok, Abonelik, Ayarlar, Çıkış |

### Detay ve form ekranları
İş detayı (fotoğraf, not, imza, tamamlama), iş formu, müşteri detayı
(sekmeli: bilgi / cari hesap / belgeler), müşteri formu, teklif ve proforma
formu (ortak gövde), belge detayı, servis talebi formu, imza alma, takvim,
finans, stok listesi, ürün formu, barkod tarama, abonelik, senkron
çakışmaları.

### Ayarlar
Profil, şirket ayarları (antet + logo), iş türleri, bildirimler, personel,
senkron durumu.

### Kimlik
Karşılama, giriş, kayıt (onboarding), açılış (splash).

## 6. Belge tasarımı (PDF) — ikinci bir tasarım yüzeyi

Uygulama, müşteriye gönderilen **A4 teklif formu / proforma fatura** üretir.
Bu, işletmenin müşterisine giden yüzüdür ve ayrı bir tasarım işi sayılabilir.

Mevcut düzen: üstte marka şeridi ve ortada belge başlığı, solda logo +
firma antedi, sağda belge künyesi (no/tarih/geçerlilik/yetkili), altında
"SAYIN" muhatap kutusu, giriş metni, numaralı malzeme tablosu, sağda
toplam paneli, iki sütunlu "Şartlar ve Notlar" + "Ödeme Bilgisi", en altta
kaşe/imza kutuları.

**Kısıt:** PDF, Flutter'ın `pdf` paketiyle programatik çiziliyor. Gömülü
font Roboto (Türkçe ş/ğ/İ için zorunlu). Tablo, kutu, çizgi, renk dolgu,
görsel yerleştirme mümkün; karmaşık grafik efektleri değil.

**Kural:** belge tek sayfada kalmalı. Müşteri ikinci sayfaya bakmıyor.

## 7. Dil ve içerik kuralları

- Arayüz dili **Türkçe**, samimi ama profesyonel; kullanıcıya **sen** diye
  hitap edilir ("Müşteri seç", "Kaydet").
- Türkçe metinler İngilizceden **%20-30 daha uzundur**. Buton ve etiket
  genişlikleri buna göre nefes almalı. "Save" 4 karakter, "Kaydet" 6;
  "Subscription" yerine "Abonelik" gibi kısalanlar da var, ikisi de olur.
- Türkçe karakterler (ç ğ ı İ ö ş ü) her fontta düzgün görünmeli. Büyük
  harf dönüşümünde `i → İ` kuralı geçerli.
- Para birimi TL/USD/EUR olabilir; tutarlar `₺1.234,50` biçiminde (nokta
  binlik, virgül ondalık).

## 8. Bilinen zayıf noktalar — tasarımdan beklenen iyileştirme

Şu an sistemin bilinçli kararları var ama görsel olarak zayıf kalan yerler:

1. **Ana sayfa** yeterince "günün özeti" hissi vermiyor.
2. **İş kartları** durum/öncelik/tarih/ücret bilgisini sıkışık gösteriyor.
3. **Uzun formlar** (teklif formu) tek uzun kaydırma; adım hissi yok.
4. **Boş durumlar** yeterince yönlendirici değil.
5. **Liste ekranları** birbirine benziyor; hiyerarşi zayıf.
6. Koyu tema, açık temanın renk çevrimi gibi duruyor; kendi başına
   tasarlanmamış.

## 9. Tasarımcıdan beklenen çıktı

Öncelik sırasıyla:

1. **Tasarım sistemi**: renk paleti (açık + koyu), tipografi ölçeği,
   boşluk ve köşe sistemi, gölge/kenarlık kuralları, durum renkleri.
2. **Bileşen kütüphanesi**: buton varyantları, kart, liste satırı, form
   alanı, rozet, çip, alt sayfa, boş durum, uyarı şeridi.
3. **Anahtar ekranlar** (bu sırayla): Ana Sayfa, İş listesi, İş detayı,
   Müşteri detayı, Teklif formu, Belge detayı, Ayarlar.
4. İkinci aşama: kalan ekranlar ve PDF belge düzeni.

**Format:** Figma tercih edilir. Değilse, her ekran için açık ve koyu
temada PNG + kullanılan tüm değerlerin (hex, punto, boşluk, yarıçap) yazılı
listesi. Değerler yazılı olmazsa uygulanamaz.

**Not:** Tasarım, yukarıdaki kullanım koşullarına (güneş, eldiven, tek el,
acele) uymayan hiçbir estetik tercihi barındırmamalı. Bu ürün bir vitrin
değil, bir alet.

## 10. Marka notu

Ürün adı **TeknikCEP**. Logo, "cep" (mobilite) ve "senkron" (offline-first
eşitleme) temalarını birleştiren bir telefon motifi + iki katmanlı sinyal
dalgasıdır. Aksan rengi `#3B82F6` markanın tek vurgu rengidir ve hem
uygulamada hem web sitesinde aynıdır.

Uygulamanın alt kısımlarında "TeknikCEP · Cicibyte Teknoloji tarafından
geliştirilmiştir" ibaresi bulunur; tasarım bunun için yer bırakmalıdır.
