# TeknikCEP — Tasarım Sistemi

**Sürüm 2.0.0 · 2026-08-25 · Mikail Özkarcı**

## Teslimat listesi

| Dosya | İçerik |
|---|---|
| `teknikcep-ekranlar.html` | 38 ekranın koyu + açık tema tasarımı (42 çerçeve), bileşen ve durum spesifikasyonları, token referansı. Kendi kendine yeterli tek dosya. |
| `teknikcep-design-tokens.json` | Tüm tokenlar, her birinde `$extensions.css` ile CSS değişkeni adı. |
| `teknikcep-icons.svg` | 94 sembollü sprite (93 ikon + marka işareti). |
| `teknikcep-logo-yonleri.html` | 4 marka işareti yönü, gerekçeleri ve ölçek testleri. |
| `logo/` | 36 SVG: her yön için işaret (aksan/siyah/beyaz), yatay ve dikey kilit (açık/koyu), uygulama simgesi 512 (açık/koyu). |
| `TeknikCEP-Tasarim-Sistemi.md` | Bu belge. |

> **Dart/Flutter kodu bu pakette yoktur.** Değerler HTML dosyasındaki CSS değişkenlerinden ve tokens JSON’undan okunur.

---

## v1.0 → v2.0 değişiklik günlüğü

| Değişiklik | Ayrıntı |
|---|---|
| **İkon seti 71 → 93** | 22 yeni ikon eklendi (aşağıda listeli). |
| **Bileşen durumları** | Buton, form alanı, sekme, arama, snackbar, diyalog, iskelet, aşağı-çekip-yenileme, çevrimdışı, hata durumu, tarih/saat seçici spesifikasyonları eklendi. |
| **Hareket spesifikasyonu** | Süre ve eğri tokenları + 20 etkileşim için tablo. Yeni bölüm. |
| **Çevrimdışı katmanları** | Global şerit, bekleyen rozeti, kayıt düzeyi işaret. Yeni bölüm. |
| **Adımlı form** | Tam düzen, hata gösterimi, adımlar arası dönüş kuralları. Yeni bölüm. |
| **Kaydırma davranışı** | Üst çubuğun kaydırmada ne yaptığı tanımlandı. Yeni bölüm. |
| **Yeni renk tokenları** | `pressOverlay`, `disabledBg/Text/Border`, `skeletonSheen`, `onSuccess/onWarning/onDanger`, `shadowSheet`, `shadowDialog`. |
| **Yeni tipografi tokenları** | `badge` (13sp/700) ve `navLabel` (13sp/600) ayrıştırıldı. |
| **Yeni ölçü tokenları** | `iconBox`, `avatar`, `stepDot`, `screenW/H`, `screenPadX`. |
| **4 yeni ekran** | Logo kırpma, müşteri seçici, belge kalemleri editörü, güncelleme bildirimi. |
| **Düzeltme: sekme sayısı** | Alt gezinme **5 sekmedir**. Servis Talepleri, İşler ekranının alt sekmesidir — envanterdeki yanlış gruplama düzeltildi. |
| **Kaldırıldı** | `teknikcep_theme.dart`. (Derlenmiyordu: `AppText` içinde `display` ve `mono` adları hem `String` hem `TextStyle` olarak iki kez tanımlıydı.) |

---

## 1. Değiştirilmeyen kararlar

Bunlar v1.0’da alındı ve v2.0’da aynen korunur:

- **`accent` / `accentSolid` ayrımı.** Marka rengi `#3B82F6` beyaz yazı altında 3.68:1 FAIL — AA’yı geçmez. Bu yüzden marka rengi ikon, kenarlık ve seçili çizgide kullanılır; beyaz yazı taşıyan **dolgular** `accentSolid` ile koyulaştırılır (koyu `#2F72E4`, açık `#1D5FD8`). Logo daima `#3B82F6`.
- **Koyu temanın kendi yüzey merdiveni:** `#0B0C0F` → `#14161B` → `#1B1E25` → `#232732`. Koyu temada gölge yoktur; derinlik yüzey katmanı ve kenarlıkla kurulur.
- **Boşluk skalası** 4 / 8 / 12 / 16 / 20 / 28 / 36 / 48 ve ekran yatay kenarı **20dp**.
- **Köşe yarıçapları** 10 / 14 / 18 / 24 / 999.
- **Sabit ölçüler:** buton 52, form alanı 56, liste satırı 72, alt gezinme 68.
- **Tipografi ölçeği** — `caption` 14sp/19sp olarak sabit.
- **Türkçe büyük harf kuralı:** `i → İ`. CSS `text-transform: uppercase` kullanılmaz.

---

## 2. Renk paleti — 45 token

CSS değişkeni adı = token adının kebab-case hâli, ön eksiz.

| Token | CSS | Koyu | Açık | Kullanım |
|---|---|---|---|---|
| `bg` | `--bg` | `#0B0C0F` | `#EEF1F5` | Ekran zemini |
| `bgSunken` | `--bg-sunken` | `#07080A` | `#E3E8EE` | Gömük bölge |
| `surface` | `--surface` | `#14161B` | `#FFFFFF` | Kart, alt sayfa, diyalog |
| `surfaceAlt` | `--surface-alt` | `#1B1E25` | `#F3F6F9` | Form alanı, gömük kart |
| `surfaceHi` | `--surface-hi` | `#232732` | `#E7ECF2` | İlerleme oluğu, pasif anahtar |
| `border` | `--border` | `#262A33` | `#D6DDE5` | Kart ve ayırıcı çizgi |
| `borderStrong` | `--border-strong` | `#39404D` | `#AEB9C6` | İkincil buton, alt sayfa üstü |
| `text` | `--text` | `#F4F6F9` | `#0C1016` | Başlık ve gövde |
| `textMuted` | `--text-muted` | `#98A2B0` | `#4A5563` | Alt açıklama, etiket |
| `textFaint` | `--text-faint` | `#7E8896` | `#68727F` | Placeholder, meta |
| `accent` | `--accent` | `#3B82F6` | `#1D5FD8` | Marka · ikon, kenarlık, seçili çizgi |
| `accentSolid` | `--accent-solid` | `#2F72E4` | `#1D5FD8` | Beyaz yazı taşıyan dolgular |
| `accentText` | `--accent-text` | `#8FBCFC` | `#174CB0` | Zemin üstünde aksan yazı |
| `accentSoft` | `--accent-soft` | `rgba(59,130,246,0.16)` | `#E4EDFD` | Vurgu kart zemini |
| `accentLine` | `--accent-line` | `rgba(59,130,246,0.42)` | `#9CC0F7` | Vurgu kart çerçevesi |
| `accentGlow` | `--accent-glow` | `rgba(59,130,246,0.28)` | `rgba(29,95,216,0.18)` | Odak halkası, FAB gölgesi |
| `onAccent` | `--on-accent` | `#FFFFFF` | `#FFFFFF` | Birincil buton yazısı |
| `success` | `--success` | `#22C55E` | `#12703A` | Tamamlandı dolgusu |
| `successText` | `--success-text` | `#5BE08C` | `#0E5B2F` | Başarı yazısı |
| `successSoft` | `--success-soft` | `rgba(34,197,94,0.16)` | `#E1F4E8` | Başarı rozet zemini |
| `successLine` | `--success-line` | `rgba(34,197,94,0.36)` | `#9BD4B1` | Başarı kenarlığı |
| `onSuccess` | `--on-success` | `#052E16` | `#FFFFFF` | Yeşil dolgu üstü yazı |
| `warning` | `--warning` | `#FBBF24` | `#9A5B06` | Bekleyen / çevrimdışı dolgusu |
| `warningText` | `--warning-text` | `#FBD268` | `#7C4805` | Uyarı yazısı |
| `warningSoft` | `--warning-soft` | `rgba(251,191,36,0.16)` | `#FCEFDA` | Uyarı rozet zemini |
| `warningLine` | `--warning-line` | `rgba(251,191,36,0.36)` | `#E8C089` | Uyarı kenarlığı |
| `onWarning` | `--on-warning` | `#3A2A03` | `#FFFFFF` | Sarı dolgu üstü yazı |
| `danger` | `--danger` | `#F87171` | `#B3231E` | Acil / borç dolgusu |
| `dangerText` | `--danger-text` | `#FCA5A5` | `#8F1B17` | Tehlike yazısı |
| `dangerSoft` | `--danger-soft` | `rgba(248,113,113,0.16)` | `#FBE7E6` | Tehlike rozet zemini |
| `dangerLine` | `--danger-line` | `rgba(248,113,113,0.36)` | `#EFAFAC` | Tehlike kenarlığı |
| `onDanger` | `--on-danger` | `#3A0A0A` | `#FFFFFF` | Kırmızı dolgu üstü yazı |
| `neutralSoft` | `--neutral-soft` | `rgba(152,162,176,0.14)` | `#E7ECF2` | Nötr rozet zemini |
| `navBg` | `--nav-bg` | `#0E1014` | `#FFFFFF` | Alt gezinme ve alt çubuk |
| `scrim` | `--scrim` | `rgba(0,0,0,0.66)` | `rgba(12,16,22,0.48)` | Perde |
| `skeleton` | `--skeleton` | `#1F232B` | `#E7ECF2` | İskelet zemini |
| `skeletonSheen` | `--skeleton-sheen` | `#2C313C` | `#F6F8FA` | İskelet parıltısı |
| `pressOverlay` | `--press-overlay` | `rgba(255,255,255,0.10)` | `rgba(12,16,22,0.08)` | Basılı durum katmanı |
| `disabledBg` | `--disabled-bg` | `#181B21` | `#EDF0F4` | Devre dışı zemin |
| `disabledText` | `--disabled-text` | `#5A6371` | `#98A2AF` | Devre dışı yazı |
| `disabledBorder` | `--disabled-border` | `#262A33` | `#DFE4EA` | Devre dışı kenarlık |
| `shadowCard` | `--shadow-card` | `none` | `0 1px 2px rgba(12,16,22,0.06), 0 6px 16px rgba(12,16,22,0.06)` | Kart gölgesi |
| `shadowRaise` | `--shadow-raise` | `0 -8px 24px rgba(0,0,0,0.55)` | `0 -6px 20px rgba(12,16,22,0.10)` | Alt çubuk gölgesi |
| `shadowSheet` | `--shadow-sheet` | `0 -16px 40px rgba(0,0,0,0.60)` | `0 -16px 40px rgba(12,16,22,0.16)` | Alt sayfa gölgesi |
| `shadowDialog` | `--shadow-dialog` | `0 24px 60px rgba(0,0,0,0.66)` | `0 24px 60px rgba(12,16,22,0.22)` | Diyalog gölgesi |

### Kontrast doğrulaması (WCAG 2.1)

| Ölçüm | Koyu | Açık | Eşik |
|---|---|---|---|
| Gövde metni / yüzey | 16.72:1 AAA | 19.07:1 AAA | 4.5:1 |
| İkincil metin / yüzey | 7.01:1 AAA | 7.58:1 AAA | 4.5:1 |
| Soluk metin / yüzey | 5.04:1 AA | 4.88:1 AA | 4.5:1 |
| Birincil buton yazısı / `accentSolid` | 4.52:1 AA | 5.71:1 AA | 4.5:1 |
| Aksan dolgu / ekran zemini (UI öğesi) | 4.33:1 AA | 5.04:1 AA | 3:1 |
| Aksan metni / zemin | 10.03:1 AAA | 7.79:1 AAA | 4.5:1 |
| Başarı metni / zemin | 11.63:1 AAA | 8.22:1 AAA | 4.5:1 |
| Uyarı metni / zemin | 13.52:1 AAA | 7.54:1 AAA | 4.5:1 |
| Tehlike metni / zemin | 10.3:1 AAA | 8.99:1 AAA | 4.5:1 |
| Yeşil dolgu üstü yazı | 6.54:1 AA | 6.17:1 AA | 4.5:1 |
| Güçlü kenarlık / yüzey (UI öğesi) | 1.74:1 FAIL | 1.99:1 FAIL | 3:1 |

> `disabledText` bilinçli olarak eşiğin altındadır — WCAG devre dışı öğeleri kontrast şartından muaf tutar; “tıklanamaz” bilgisi bu düşük kontrastla taşınır.

---

## 3. Tipografi

Archivo (başlık) · Barlow (arayüz) · JetBrains Mono (tutar, kod).

| Token | Aile | Ağırlık | Punto / satır | Harf aralığı | Kullanım |
|---|---|---|---|---|---|
| `display` | Archivo | 700 | 32sp / 38sp | -0.6 | Karşılama başlığı |
| `h1` | Archivo | 700 | 24sp / 30sp | -0.3 | Ekran başlığı |
| `h2` | Archivo | 600 | 19sp / 26sp | -0.2 | Bölüm başlığı |
| `h3` | Barlow | 600 | 17sp / 24sp | 0 | Kart / liste başlığı |
| `body` | Barlow | 400 | 16sp / 24sp | 0 | Okunan metin (taban) |
| `bodyS` | Barlow | 600 | 16sp / 24sp | 0 | Vurgulu gövde, değer |
| `label` | Barlow | 600 | 14sp / 20sp | 0 | Form etiketi, çip, sekme |
| `labelUp` | Barlow | 700 | 12sp / 16sp | 0.8 | Bölüm üst etiketi (BÜYÜK) |
| `caption` | Barlow | 500 | 14sp / 19sp | 0 | Alt açıklama, liste alt satırı |
| `badge` | Barlow | 700 | 13sp / 18sp | 0 | Rozet metni |
| `navLabel` | Barlow | 600 | 13sp / 15sp | 0 | Alt gezinme etiketi |
| `mono` | JetBrains Mono | 600 | 18sp / 24sp | 0 | Tutar, belge no (tabular) |
| `monoS` | JetBrains Mono | 500 | 14sp / 19sp | 0.2 | Küçük kod, barkod |
| `monoL` | JetBrains Mono | 700 | 28sp / 34sp | -0.5 | Özet rakamı |

**Türkçe kuralları**

- `labelUp` stilinde CSS `text-transform: uppercase` **kullanılmaz** — varsayılan yerelde `i → I` üretir ve “BUGÜNÜN ÖZETI” çıkar. Metin baştan büyük yazılır ya da `i → İ`, `ı → I` eşlemesi yapan bir yardımcıdan geçirilir.
- Türkçe etiketler İngilizceden %20-30 uzundur. Buton yatay iç boşluğu 20dp, metin tek satır (`nowrap`); liste satırında taşan metin **…** ile kesilir.
- Alt çubukta sol slot **128dp sabittir** — “İptal”, “Geri”, “Reddet”, “Temizle” hepsi sığar.
- Tutarlar `₺1.234,50` (nokta binlik, virgül ondalık), `tabular-nums` ile hizalanır. Kısaltma virgüllüdür: `₺82,4K`.

---

## 4. Boşluk, yarıçap ve ölçü

| Grup | Token → CSS | Değer |
|---|---|---|
| Boşluk | `space.xs` → `--space-xs` | 4dp |
| Boşluk | `space.sm` → `--space-sm` | 8dp |
| Boşluk | `space.md` → `--space-md` | 12dp |
| Boşluk | `space.lg` → `--space-lg` | 16dp |
| Boşluk | `space.xl` → `--space-xl` | 20dp |
| Boşluk | `space.xxl` → `--space-xxl` | 28dp |
| Boşluk | `space.x3l` → `--space-x3l` | 36dp |
| Boşluk | `space.x4l` → `--space-x4l` | 48dp |
| Yarıçap | `radius.sm` → `--radius-sm` | 10dp |
| Yarıçap | `radius.field` → `--radius-field` | 14dp |
| Yarıçap | `radius.card` → `--radius-card` | 18dp |
| Yarıçap | `radius.dialog` → `--radius-dialog` | 24dp |
| Yarıçap | `radius.pill` → `--radius-pill` | 999dp |
| Ölçü | `size.btnPrimary` → `--size-btn-primary` | 52dp |
| Ölçü | `size.btnSecondary` → `--size-btn-secondary` | 50dp |
| Ölçü | `size.field` → `--size-field` | 56dp |
| Ölçü | `size.rowMin` → `--size-row-min` | 72dp |
| Ölçü | `size.touch` → `--size-touch` | 48dp |
| Ölçü | `size.nav` → `--size-nav` | 68dp |
| Ölçü | `size.appBar` → `--size-app-bar` | 60dp |
| Ölçü | `size.fab` → `--size-fab` | 56dp |
| Ölçü | `size.safeTop` → `--size-safe-top` | 44dp |
| Ölçü | `size.safeBottom` → `--size-safe-bottom` | 14dp |
| Ölçü | `size.screenW` → `--size-screen-w` | 390dp |
| Ölçü | `size.screenH` → `--size-screen-h` | 844dp |
| Ölçü | `size.screenPadX` → `--size-screen-pad-x` | 20dp |
| Ölçü | `size.iconBox` → `--size-icon-box` | 46dp |
| Ölçü | `size.avatar` → `--size-avatar` | 46dp |
| Ölçü | `size.stepDot` → `--size-step-dot` | 32dp |

**Gölge**

| Tema | Kart | Alt çubuk | Alt sayfa | Diyalog |
|---|---|---|---|---|
| Koyu | none (kenarlık kullanılır) | `0 -8px 24px rgba(0,0,0,0.55)` | `0 -16px 40px rgba(0,0,0,0.60)` | `0 24px 60px rgba(0,0,0,0.66)` |
| Açık | `0 1px 2px rgba(12,16,22,0.06), 0 6px 16px rgba(12,16,22,0.06)` | `0 -6px 20px rgba(12,16,22,0.10)` | `0 -16px 40px rgba(12,16,22,0.16)` | `0 24px 60px rgba(12,16,22,0.22)` |

---

## 5. Bileşen durumları

Tam görsel spesifikasyon `teknikcep-ekranlar.html` → **Bileşenler ve durumlar** bölümündedir. Özet kurallar:

### Buton — 3 varyant × 4 durum

| Durum | Kural |
|---|---|
| Varsayılan | birincil 52dp `--accent-solid`; ikincil 50dp `--surface` + `--border-strong`; tehlike `--danger-soft` + `--danger-line` |
| Basılı | `--press-overlay` katmanı + `scale(.98)` · 90ms |
| Yükleniyor | 20dp spinner (2,4dp çizgi, 900ms tur) ikonun yerine geçer; metin “…” ile değişir; buton tıklanamaz |
| Devre dışı | `--disabled-bg` / `--disabled-text` / `--disabled-border`; gölge yok |

Ekran başına **bir** birincil buton. Tehlike butonu asla dolu kırmızı değildir.

### Form alanı — 7 durum

varsayılan · odaklanmış · dolu-geçerli · hatalı · salt-okunur · devre dışı · çok satırlı.
Odak: 1px `--accent` + 3px `--accent-glow` halka. Hata metni **alanın altında**, 15dp ikonla; asla placeholder’a gömülmez. Salt-okunur: şeffaf zemin + **kesikli** kenarlık.

### Sekme çubuğu

Dokunma yüksekliği **48dp**. Yazı Barlow 600 · 14sp. Alt çizgi 3dp `--accent`, 200ms kayar.
**Sekme** = aynı nesnenin farklı görünümleri (Bilgi / Cari / Belgeler). **Segment** = aynı listenin filtresi (Bu Ay / Geçen Ay / Yıl).

### Arama alanı

Yükseklik 56dp, yarıçap `--radius-pill`. Sağda 48dp temizle butonu yalnızca değer varken görünür. Canlı filtreleme; sonuç yoksa liste yerine **boş durum** gösterilir (hata durumu değil).

### Snackbar / Toast

Alt gezinme çubuğunun **üstünde**: alttan **96dp** (nav 68 + güvenli alan 14 + 14dp). Alt çubuk yoksa 24dp. Süre: bilgi 3 sn, geri-al 6 sn, hata elle kapanır. Giriş 220ms `--ease-decelerate`.

### Onay diyaloğu

Yarıçap 24dp, kenardan 20dp içeride, 52dp ikon kutusu.
**Normal:** birincil = onay. **Yıkıcı:** birincil = **Vazgeç**, tehlike varyantı altta; yıkıcı eylem asla varsayılan odak değildir.

### İskelet yükleme

Dönen daire kullanılmaz. Üç desen: liste satırı (3 satır), kart (2 kart), detay ekranı (1 blok). Parıltı 1400ms `linear`. İskeletten içeriğe geçiş 280ms çapraz opacity, düzen kaymaz. **500 ms’den kısa yüklemede iskelet gösterilmez.**

### Aşağı çekip yenileme

72dp çekince tetiklenir; 56dp alan açılır; 26dp halka `--accent`. Çevrimdışıyken halka görünmez, doğrudan “Bağlantı yok — kayıtlar cihazda” snackbar’ı çıkar.

---

## 6. Çevrimdışı — üç katman

Bu ürünün güven kazandığı yer. Üç ayrı katman birlikte çalışır.

### 6.1 Global çevrimdışı şeridi

| Özellik | Karar |
|---|---|
| Konum | Üst çubuğun **hemen altında**, içeriğin üstünde |
| Gezinmeyi iter mi | **Evet** — üstüne binmez, aşağı iter; hiçbir eylem örtülmez |
| Yükseklik | 36dp · yatay iç boşluk 20dp |
| Kapatılabilir mi | **Hayır.** Bağlantı gelene kadar kalır. Kapatılabilir olsaydı kullanıcı durumu kaybederdi. Yalnızca dokunulabilir → Eşitleme Durumu ekranı |
| Çevrimdışı | `--warning-soft` zemin, `--warning-line` alt çizgi, `--warning-text` yazı, `cloudOff` ikonu |
| Eşitleniyor | `--accent-soft` / `--accent-line` / `--accent-text`, `sync` ikonu, “Eşitleniyor… 2/3” |
| Tamamlandı | `--success-soft`, 2 sn görünür, sonra 200ms yüksekliği 0’a inerek kapanır |

### 6.2 “Bekleyen N kayıt” rozeti

48dp yükseklik · `--warning-soft` + `--warning-line` · sayı JetBrains Mono 700 · 14sp.
İşler, Müşteriler ve Belgeler sekmelerinin üst çubuğunda durur. **Sayı 0 olunca tamamen kaybolur** — “0 bekliyor” yazmak gürültüdür.

### 6.3 Kaydedildi-ama-gönderilmedi kartı

| | Eşitlenmiş kart | Bekleyen kart |
|---|---|---|
| Sol kenar | işaret yok | **3dp `--warning` çubuk** (`.card.is-pending::before`) |
| Alt satır | işaret yok | `cloudOff` ikonu + **“Cihazda · gönderilmedi”** · `--warning-text` |
| Ayırıcı | — | kesikli `--warning-line` |
| Detay ekranında | `cloudOk` + “Eşitlendi” | `cloudOff` + “cihaza kaydedildi, gönderilmedi” |

**Sessizlik iyi haberdir:** eşitlenmiş kayda hiçbir ek işaret konmaz; yalnızca bekleyen kayıt işaretlenir.

**Dil kuralı:** Kaydetme anında “gönderiliyor” yalanı söylenmez. Metin daima cihaz gerçeğini anlatır: *“cihaza kaydedildi”*, *“bağlantı gelince gönderilecek”*.

### 6.4 Tam ekran hata durumu ≠ boş durum

| | Boş durum | Hata durumu |
|---|---|---|
| Söylediği | “henüz yok” | “bir şey ters gitti” |
| İkon kutusu | `--surface-alt` + `--text-faint` | `--danger-soft` + `--danger-line` + `--danger-text` |
| Birincil eylem | **ileri** — “Yeni İş Oluştur” | **tekrar** — “Tekrar Dene” |
| İkincil eylem | yok | “Çevrimdışı devam et” (metin buton) |
| Zorunlu cümle | — | Cihazdaki verinin güvende olduğu söylenir |

Teknik hata kodu kullanıcıya gösterilmez; “Bize Yaz” ekranına otomatik eklenir.

---

## 7. Adımlı form

Düzen: **üstte** başlık + adım göstergesi · **ortada** içerik · **altta** sabit “Geri / Devam”.

| Konu | Kural |
|---|---|
| Daire | 32dp görünür, dokunma alanı 48dp’ye tamamlanır |
| Tamamlanan | `--success` + `--on-success` onay ikonu |
| Aktif | `--accent-solid` + `--on-accent` rakam, etiket 700 ağırlık |
| Bekleyen | `--surface-hi` + `--text-faint` |
| Hatalı / eksik | `--danger-soft` + 1px `--danger` + uyarı ikonu; etiket `--danger-text` |
| Geri dönüş | Adım dairesine dokunmak o adıma gider. Girilen veri **korunur**; doğrulama o adımda yeniden çalışır |
| Hata nerede görünür | ① alanın altında satır ② adım dairesi kırmızı ③ içeriğin en üstünde özet şerit |
| İleri butonu | zorunlu alan boşken `is-disabled`; kullanıcı nedenini üstteki şeritten okur |
| Alt çubuk | sol “Geri” **128dp sabit**, sağ “Devam” esner; son adımda “Oluştur ve Gönder” |
| Taslak | Her adım geçişinde taslak cihaza yazılır; uygulama kapansa da veri kaybolmaz |

---

## 8. Kaydırma davranışı

Üst çubuk **sabittir, küçülmez**. İçerik 8dp kayınca yalnızca **1px çizgi + hafif gölge** kazanır (200ms `--ease-standard`). Yükseklik değişmez, başlık daima okunur, düzen zıplamaz.

- Çevrimdışı şerit üst çubukla birlikte sabit kalır.
- Alt gezinme, alt çubuk ve FAB kaydırmayla **gizlenmez** — sahada eylem kaybolmamalı.
- Liste sonunda alt çubuk yüksekliği kadar boşluk bırakılır.

---

## 9. Hareket spesifikasyonu

### Tokenlar

| CSS | Değer | Nerede |
|---|---|---|
| `--dur-micro` | 90ms | basma geri bildirimi |
| `--dur-fast` | 140ms | rozet/çip değişimi |
| `--dur-base` | 200ms | sekme çizgisi, şerit |
| `--dur-slow` | 280ms | iskelet→içerik |
| `--dur-page` | 260ms | sayfa geçişi |
| `--dur-sheet` | 320ms | alt sayfa açılma |
| `--dur-sheet-out` | 240ms | alt sayfa kapanma |
| `--dur-dialog` | 200ms | diyalog açılma |
| `--dur-toast` | 220ms | snackbar |
| `--dur-shimmer` | 1400ms | iskelet parıltısı |
| `--dur-spinner` | 900ms | buton spinner |
| `--ease-standard` | `cubic-bezier(0.2, 0, 0, 1)` | genel amaçlı |
| `--ease-decelerate` | `cubic-bezier(0.05, 0.7, 0.1, 1)` | giriş (yavaşlayarak yerleşir) |
| `--ease-accelerate` | `cubic-bezier(0.3, 0, 0.8, 0.15)` | çıkış (hızlanarak kaybolur) |
| `--ease-emphasized` | `cubic-bezier(0.16, 1, 0.3, 1)` | vurgulu geçiş |
| `--ease-linear` | `linear` | sonsuz döngü |

### Etkileşim tablosu

| Etkileşim | Süre | Eğri | Ne oynatılır |
|---|---|---|---|
| Sayfa geçişi (ileri) | 260ms | standard | Yeni ekran sağdan %8 kayar + opacity 0→1; eski ekran %2 sola |
| Sayfa geçişi (geri) | 260ms | standard | Ters yön; Android geri tuşu ve kenar jesti aynı eğri |
| Alt sayfa açılma | 320ms | decelerate | translateY %100→0; perde opacity aynı sürede |
| Alt sayfa kapanma | 240ms | accelerate | translateY 0→%100 |
| Diyalog açılma | 200ms | decelerate | opacity 0→1 + scale .94→1 |
| Diyalog kapanma | 140ms | accelerate | opacity 1→0 + scale 1→.96 |
| Buton basma | 90ms | standard | scale 1→.98 + press-overlay |
| Çip / segment seçimi | 140ms | standard | Zemin ve yazı rengi çapraz geçiş |
| Sekme altı çizgi | 200ms | standard | Çizgi yatayda kayar, içerik çapraz geçer |
| Rozet / durum değişimi | 140ms | standard | Renk geçişi; **boyut değişmez**, satır zıplamaz |
| Çevrimdışı şerit girişi | 200ms | decelerate | height 0→36dp; içerik aşağı iter |
| Çevrimdışı şerit çıkışı | 200ms | accelerate | 2 sn bekler, sonra height 36→0 |
| İskelet parıltısı | 1400ms | linear ∞ | Gradyan soldan sağa |
| İskelet → içerik | 280ms | standard | Çapraz opacity; düzen kaymaz |
| Snackbar | 220ms | decelerate | translateY 12dp→0 + opacity |
| Aşağı çekip yenileme | 200ms | accelerate | 56dp alan yukarı toplanır |
| Buton spinner | 900ms | linear ∞ | 360° |
| FAB basma | 90ms | standard | scale 1→.96 |
| Anahtar (switch) | 140ms | standard | Topuz 22dp kayar + zemin rengi |
| İlerleme çubuğu | 280ms | standard | width geçişi |

**Erişilebilirlik:** Sistemde “animasyonları azalt” açıkken tüm süreler 0’a iner; yalnızca opacity geçişleri korunur. 320 ms’yi yalnızca alt sayfa aşar.

---

## 10. İkon seti — 93 sembol

24×24 ızgara · `stroke-width` 1.7dp (aktifken 2.1dp) · `round` uç ve birleşim · dolgu yok.
Kullanım: `<svg class="ic"><use href="teknikcep-icons.svg#tc-briefcase"/></svg>` — renk `currentColor`.

**v2.0’da eklenen 22 ikon:**
`send`, `arrowUp`, `arrowDown`, `chevronUp`, `moreH`, `bank`, `inbox`, `userPlus`, `userOff`, `userSearch`, `syncProblem`, `bellOff`, `flag`, `bulb`, `map`, `badge`, `imageBroken`, `category`, `listPlus`, `crop`, `pdf`, `sparkle`

**Tam liste:**
```
home, briefcase, users, file, grid, plus, minus, search, filter, calendar, wallet, box, barcode, bell, user, building, settings, sync, cloudOff, cloudOk, check, checkCircle, alert, alertCircle, info, x, chevronRight, chevronLeft, chevronDown, arrowLeft, arrowRight, phone, pin, camera, pen, signature, clock, trash, edit, download, share, card, shield, logout, moreV, image, note, trendUp, trendDown, scan, tag, lock, mail, eye, list, flash, star, printer, key, upload, folder, chart, sun, moon, layers, percent, wrench, wifi, refresh, copy, swap, send, arrowUp, arrowDown, chevronUp, moreH, bank, inbox, userPlus, userOff, userSearch, syncProblem, bellOff, flag, bulb, map, badge, imageBroken, category, listPlus, crop, pdf, sparkle
```

---

## 11. Ekran envanteri — 38 ekran

**Alt gezinme 5 sekmedir:** Ana Sayfa · İşler · Müşteriler · Belgeler · Daha Fazla.
**Servis Talepleri** bir alt gezinme sekmesi değildir — İşler ekranının ikinci sekmesidir.

### Sekmeler

| # | Ekran | Kimlik |
|---|---|---|
| 1 | Ana Sayfa | `Home` |
| 2 | İşler | `Jobs` |
| 8 | Belgeler | `Documents` |
| 9 | Müşteriler | `Customers` |
| 10 | Daha Fazla | `More` |
| 19 | Servis Talepleri (İşler alt sekmesi) | `ServiceRequests` |

### İş Akışı

| # | Ekran | Kimlik |
|---|---|---|
| 3 | İş Detayı | `JobDetail` |
| 11 | İş Tamamlama | `JobComplete` |
| 12 | İmza Alma | `Signature` |
| 20 | İş Formu | `JobForm` |
| 23 | Servis Talebi Formu | `ServiceRequestForm` |

### Müşteri

| # | Ekran | Kimlik |
|---|---|---|
| 4 | Müşteri Detayı | `CustomerDetail` |
| 21 | Cari Hesap | `CustomerLedger` |
| 22 | Müşteri Formu | `CustomerForm` |

### Belge

| # | Ekran | Kimlik |
|---|---|---|
| 5 | Teklif Formu · 1 Müşteri | `QuoteStep1` |
| 6 | Belge Detayı | `DocumentDetail` |

### Ayarlar

| # | Ekran | Kimlik |
|---|---|---|
| 7 | Ayarlar | `Settings` |
| 31 | Profil | `Profile` |
| 32 | Şirket Ayarları | `CompanySettings` |
| 33 | İş Türleri | `JobTypes` |
| 34 | Bildirimler | `Notifications` |
| 35 | Personel | `Staff` |
| 36 | Eşitleme Durumu | `SyncStatus` |

### Belge · YENİ

| # | Ekran | Kimlik |
|---|---|---|
| 13 | Belge Kalemleri Editörü **· YENİ** | `LineItemsEditor` |

### Müşteri · YENİ

| # | Ekran | Kimlik |
|---|---|---|
| 14 | Müşteri Seçici (alt sayfa) **· YENİ** | `CustomerPicker` |

### Kimlik

| # | Ekran | Kimlik |
|---|---|---|
| 15 | Açılış | `Splash` |
| 16 | Karşılama | `Welcome` |
| 17 | Giriş | `Login` |
| 18 | Kayıt / Onboarding | `Register` |

### İşletme

| # | Ekran | Kimlik |
|---|---|---|
| 24 | Takvim | `Calendar` |
| 25 | Finans | `Finance` |
| 26 | Stok Listesi | `Stock` |
| 27 | Ürün Formu | `ProductForm` |
| 28 | Barkod Tarama | `BarcodeScan` |

### Hesap

| # | Ekran | Kimlik |
|---|---|---|
| 29 | Abonelik | `Subscription` |
| 30 | Eşitleme Çakışmaları | `SyncConflicts` |

### Ayarlar · YENİ

| # | Ekran | Kimlik |
|---|---|---|
| 37 | Logo Kırpma **· YENİ** | `LogoCrop` |

### Sistem · YENİ

| # | Ekran | Kimlik |
|---|---|---|
| 38 | Güncelleme · İsteğe Bağlı (şerit) **· YENİ** | `AppUpdate` |

Teklif Formu dört adımın hepsiyle çizilmiştir (`QuoteStep1–4`); envanterde tek ekran sayılır. Güncelleme bildiriminin zorunlu diyalog varyantı `AppUpdateForced` olarak ayrıca çizilmiştir.

---

## 12. Marka işareti — 4 yön

Dördü de aynı kısıtla çizildi: **tek kapalı yol, negatif alan, çizgi kalınlığı yok.** Bu yüzden hepsi tek renkte, düz siyahta, düz beyazda ve gri tonlamada çalışır; 16px’te blob’a dönüşmez.

### A · Somun — `teknikcep-a-somun`

Altıgen somun, alet dünyasının evrensel formudur; negatif alandaki T hem “Teknik”i hem tornavida ucunu okutur. Tek parça dolu geometri olduğu için 16px’te bile blob’a dönüşmez.

> **Zayıf yanı:** Teknik sektörde altıgen sık kullanılır; ayırt ediciliği T’nin oranına bağlıdır.

### B · Plaka — `teknikcep-b-plaka`

Köşesi kesilmiş ekipman/envanter plakası: sahada her cihazın üstünde bulunan künye. Kurumsal ve sağlam; PDF antedinde küçük basıldığında en yüksek siyah alana sahip olduğu için en okunaklı yön.

> **Zayıf yanı:** Kesik köşe çok küçükte kaybolur; 16px’te yuvarlak kareye yaklaşır.

### C · Kıskaç — `teknikcep-c-kiskac`

“CEP”in C’si bir kumpas ağzına dönüşür; ağzındaki blok, ölçülen parçayı tutan sürgülü çeneyi anlatır. Dört yön içinde en az kullanılan form, dolayısıyla en ayırt edici olanı.

> **Zayıf yanı:** Açık form olduğu için çok küçükte “C” harfi yerine soyut bir kanca gibi okunabilir; kelime markasıyla birlikte kullanılması önerilir.

### D · Kalkan — `teknikcep-d-kalkan`

Kalkan + onay işareti: garanti, iş tamamlandı, güven. Servis sektörünün en doğrudan vaadi. Dolu kalkan yüksek siyah alan verir, negatif onay her ölçekte okunur.

> **Zayıf yanı:** Kalkan+tik güvenlik ve antivirüs yazılımlarında yaygın; teknik servis çağrışımı zayıf kalabilir.

**Kilit kuralları**

- Koruma alanı: işaretin her yanında işaret yüksekliğinin **%25**’i kadar boşluk.
- Yatay kilitte işaret ile yazı arası bu boşluğun yarısı.
- Renk: işaret `#3B82F6`; “Teknik” metin rengi, “CEP” `#3B82F6`.
- Üretim: seçilen yönün sözcük markası **outline’a çevrilir**; teslim edilen SVG’lerdeki `<text>` yalnızca sunum içindir.
- En küçük kullanım: işaret 16px, yatay kilit 120px genişlik.

---

## 13. Bilinen zayıf noktalara verilen cevaplar

| # | Sorun (brief madde 8) | Cevap |
|---|---|---|
| 1 | Ana sayfa “günün özeti” hissi vermiyor | Tek büyük rakam (“4 iş planlı”) + üç istatistik + “Sıradaki iş” kartı + çevrimdışı şeridi |
| 2 | İş kartları sıkışık | İki katmanlı kart: üstte ikon + başlık + müşteri; ayırıcı; altta durum rozeti + tarih/saat + tutar. Başlık tam genişlik |
| 3 | Uzun formlarda adım hissi yok | Teklif formu 4 adıma bölündü; adım göstergesi dokunulabilir, hata adımda işaretlenir |
| 4 | Boş durumlar yönlendirici değil | Her boş durum ne olduğunu söyler, tek birincil eylem sunar; hata durumundan görsel olarak ayrıdır |
| 5 | Liste ekranları birbirine benziyor | Müşteriler harf gruplu düz liste · İşler kart listesi · Belgeler monospace belge no + tutar · Stok sağda büyük miktar |
| 6 | Koyu tema renk çevrimi gibi | Koyu temanın kendi yüzey merdiveni, gölge yerine kenarlık, ayrı seçilmiş durum renkleri |

---

TeknikCEP · Cicibyte Teknoloji tarafından geliştirilmiştir
Tasarım ve tasarım sistemi: Mikail Özkarcı · v2.0.0 · 2026-08-25
