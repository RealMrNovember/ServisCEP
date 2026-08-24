# 14 — Marka Kimliği

> Bu doküman, geliştirme sürecinde eklenen bir gereksinimdir (bkz. [ROADMAP.md § Ek Gereksinimler](../ROADMAP.md#ek-gereksinimler-sonradan-eklenen)).

## Konsept

Logo, "**cep**" (mobilite/telefon) ve "**senkron**" (offline-first senkronizasyon — bkz. [08](08-offline-first-ve-senkronizasyon.md)) temalarını birleştiren bir telefon/cihaz motifi + iki katmanlı sinyal dalgasından oluşur.

## Kaynak Dosyalar

Tüm marka varlıkları [`assets/branding/`](../assets/branding/) altındadır:

| Dosya | Kullanım |
|---|---|
| `icon.svg` | Vektör kaynak — her zaman güncel tutulacak tek doğruluk kaynağı |
| `generate_assets.py` | `icon.svg` ile birebir eşleşen PNG/ICO çıktıları üreten Python (Pillow) scripti |
| `icon-{16,32,64,128,180,192,512}.png` | Farklı boyutlarda raster ikon (favicon, PWA, mobil app icon vb.) |
| `favicon.ico` | Çok boyutlu (16/32/48) favicon |
| `apple-touch-icon.png` | iOS/Safari ana ekran ikonu (180×180) |

Herhangi bir tasarım değişikliğinde: `icon.svg`'yi düzenle → `python generate_assets.py` çalıştır → tüm PNG/ICO çıktıları otomatik yeniden üretilir.

## Renk Paleti

| Rol | Hex | Kullanım |
|---|---|---|
| Arka plan (koyu) | `#131316` | İkon zemini, koyu tema yüzeyleri |
| Bezel / ikincil yüzey | `#3F3F46` | Telefon çerçevesi, ikincil detaylar |
| Ekran / açık yüzey | `#FAFAFA` | Telefon ekranı, açık yüzeyler |
| Ekran detay (soluk) | `#D4D4D8` | Home bar gibi düşük vurgulu detaylar |
| **Aksan** | `#3B82F6` | Senkron dalgası, CTA butonları, linkler — markanın tek vurgu rengi |
| Beyaz | `#FFFFFF` | Dış sinyal dalgası, kontrast metinler |

> Aksan rengi (`#3B82F6`) tutarlılık için hem mobil uygulamada hem web arayüzünde (bkz. [13](13-web-arayuzu-ve-showroom.md)) birincil vurgu rengi olarak kullanılmalıdır.

## Kullanım Alanları

- **Favicon / site ikonu:** `deploy/public-placeholder/` içine kopyalanır, `deploy/apply.sh` tarafından her deploy'da site köküne yerleştirilir.
- **Mobil uygulama ikonu:** `assets/branding/icon-512.png` kaynak alınarak `flutter_launcher_icons` ile Android/iOS launcher icon setleri üretilir (bkz. [mobile/README.md](../mobile/README.md)). ✅ Tamamlandı.
- **Web/Showroom:** [13 — Web Arayüzü ve Showroom](13-web-arayuzu-ve-showroom.md) kapsamında header/hero alanlarında kullanılır.

## Geliştirici Atfı (Zorunlu)

> **Zorunlu gereksinim:** "TeknikCEP · **Cicibyte Teknoloji** tarafından geliştirilmiştir" ibaresi, [cicibyte.com](https://cicibyte.com) bağlantısıyla, gerçekten olması gereken footer alanlarında gösterilmelidir:

- **Mobil:** Ana ekranların altında (bkz. `mobile/lib/shared/brand_footer.dart`, şu an Dashboard'da kullanılıyor) ve ileride eklenecek "Daha Fazla / Hakkında" ekranında.
- **Web (Showroom + Panel):** Sayfa footer'ında, tüm sayfalarda tutarlı şekilde.

Bu, Claude/Anthropic atfı **değildir** — TeknikCEP'i geliştiren şirketin kendi atfıdır, kullanıcı talebiyle eklenmiştir ve her yeni ekran/sayfada bu kurala uyulmalıdır.
