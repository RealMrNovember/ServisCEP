# 13 — Web Arayüzü ve Showroom

> Bu doküman, orijinal spesifikasyonun ötesinde geliştirme sürecinde eklenen bir gereksinimdir (bkz. [ROADMAP.md § Ek Gereksinimler](../ROADMAP.md#ek-gereksinimler-sonradan-eklenen)). Orijinal spesifikasyon web paneli yalnızca V2 kapsamında öngörüyordu (§58); bu doküman kapsamı iki parçaya ayırarak netleştirir: **herkese açık showroom** (erken başlanabilir) ve **web panel** (API'ler hazır olunca).

TeknikCEP'in web varlığı iki ayrı amaca hizmet eder:

1. **Showroom (Tanıtım Sitesi)** — `serviscep.cicibyte.com` üzerinde herkese açık, ürünü tanıtan, giriş/kayıt akışına ve APK indirmeye yönlendiren profesyonel bir açılış sayfası.
2. **Web Panel** — mobil uygulamayla **aynı Laravel API'yi** tüketen, tarayıcı üzerinden tam işlevsel bir yönetim arayüzü (masaüstünden çalışmak isteyen kullanıcılar için).

Bu iki parça aynı domain altında, kimlik doğrulama durumuna göre ayrışır: giriş yapmamış ziyaretçi showroom'u görür, giriş yapmış kullanıcı panele yönlendirilir.

## 1. Showroom (Tanıtım Sitesi)

### Amaç

Ziyaretçiye ürünü profesyonelce tanıtmak, giriş/kayıt akışına ve APK indirmeye yönlendirmek.

### Kapsam

- Hero bölümü — ürün vaadi (bkz. [01 — Vizyon ve Felsefe](01-vizyon-ve-felsefe.md))
- Özellik tanıtımı (müşteri yönetimi, servis formu, teklif/proforma, finans, offline-first)
- **Mobil uygulama ekran görüntüleri / showcase** — mobil UI tamamlandığında eklenir (bkz. §5 aşağıda)
- **Giriş (Login) ve Kayıt (Signup)** butonları — zorunlu, sayfanın her yerinden erişilebilir
- **"Uygulamayı İndir" (APK)** — zorunlu, öne çıkan bir CTA (bkz. §2 aşağıda)
- İletişim/CTA alanı

### Kimlik Doğrulama Giriş Noktası

Showroom'daki Login/Signup, [09 — Güvenlik ve Yetkilendirme § Kimlik Doğrulama Yöntemleri](09-guvenlik-ve-yetkilendirme.md#0-kimlik-doğrulama-yöntemleri) içinde tanımlanan akışı kullanır (e-posta+parola ve Google OAuth).

## 2. APK İndirme (Play Store Yerine)

> **Zorunlu gereksinim:** Uygulama şu aşamada Play Store'da lisanslanamadığı için, showroom'u ziyaret eden herkes uygulamayı **doğrudan siteden, tek tıkla** indirebilmelidir — her zaman **en güncel sürüm**.

- **Konum:** Showroom'da göze çarpan, öne çıkan bir "Uygulamayı İndir" butonu/bölümü (hero alanına yakın, aşağı kaydırmadan görünür).
- **Mekanizma:** Buton, GitHub Releases'in sabit "latest" URL desenine yönlendirir — yeni sürüm yayınlandığında bağlantı **değişmeden** en güncel APK'yı verir:
  ```
  https://play.google.com/store/apps/details?id=com.cicibyte.serviscep
    (NOT 2026-08-23: GitHub Release/APK kanalı kapatıldı — dağıtım yalnızca Google Play)
  ```
  Aynı mekanizma, mobil uygulamanın kendi otomatik güncelleme kontrolü için de kullanılır — bkz. [06 — Teknik Mimari § Mobil Uygulama Otomatik Güncelleme](06-teknik-mimari.md#mobil-uygulama-otomatik-güncelleme-ota).
- **İçerik:** İndirme alanı yalnızca bir link değil, kullanıcıya güven verecek kısa bir kurulum rehberi de içermelidir — "Bilinmeyen kaynaklardan yükleme" izni gerektiği kısaca açıklanmalı (Play Store dışı kurulum olduğu için).
- **Durum:** İlk gerçek sürüm (MVP release, Sprint 8) yayınlanana kadar bu bölüm showroom'da **yer almaz** — sahte/çalışmayan bir buton göstermek yerine, ilk release ile birlikte canlıya alınır.

## 3. Web Panel

### Amaç

Masaüstünden çalışmayı tercih eden kullanıcılar (ör. ofis/finans işleri) için, mobil ile **feature parity** hedefleyen tam işlevsel bir arayüz.

### Kapsam (Mobil ile Paralel)

Web panel, mobil uygulamanın tüm ana modüllerini kapsar:

- Müşteri yönetimi ([02](02-is-alani-ve-veri-modeli.md))
- İş/Servis yönetimi, talepler ([02](02-is-alani-ve-veri-modeli.md))
- Servis formu, belge merkezi, teklif/proforma/fatura ([03](03-servis-ve-belge-yonetimi.md))
- Finans ve stok ([04](04-finans-ve-stok.md))
- Takvim, bildirimler ([05](05-takvim-bildirim-iletisim.md))

### Mimari Yaklaşım

Web panel, mobil uygulamayla **aynı Laravel API'yi** tüketir (bkz. [07 — API ve Veritabanı](07-api-ve-veritabani.md)) — ayrı bir backend veya veri modeli oluşturulmaz. Bu, çift bakım yükünü önler ve `company_id` izolasyonu gibi kritik güvenlik kurallarının tek bir katmanda uygulanmasını sağlar (bkz. [07 § Şirket Bazlı Veri Ayrımı](07-api-ve-veritabani.md#5-şirket-bazlı-veri-ayrımı-multi-tenancy)).

Frontend teknolojisi (React/Vue/Inertia.js gibi) **Phase W3 başlangıcında** güncel ve stabil seçenekler değerlendirilerek kesinleştirilecektir — [06 — Teknik Mimari](06-teknik-mimari.md) içindeki "kütüphane seçimi geliştirme anında netleşir" prensibiyle tutarlı.

## 4. Kimlik Doğrulama ve Yetkilendirme

Web panel, [09 — Güvenlik ve Yetkilendirme](09-guvenlik-ve-yetkilendirme.md) içindeki rol/yetki modelini birebir uygular — mobilde geçerli olan (`OWNER`, ileride `ADMIN`/`TECHNICIAN`/`ACCOUNTING`/`VIEWER`) kısıtlamalar web tarafında da sunucu düzeyinde zorunlu kılınır. Web arayüzünün varlığı, [11 — Geliştirme Prensipleri](11-gelistirme-prensipleri.md) içindeki *"yetkilendirme yalnızca frontend'e bırakılmaz"* kuralını daha da kritik hale getirir — iki farklı istemci (mobil + web) aynı sunucu taraflı policy'lere güvenmelidir.

## 5. Mobil Showcase Entegrasyonu

Mobil uygulamanın modern arayüzü tamamlandığında (Sprint 8 / MVP release civarı, bkz. [ROADMAP.md](../ROADMAP.md)), gerçek ekran görüntüleri ve/veya kısa ekran kayıtları showroom sayfasına eklenmelidir. Bu adım, showroom'un ilk sürümünde **placeholder/mockup görsellerle** başlayıp mobil UI olgunlaştıkça gerçek görsellerle güncellenmesi şeklinde ilerler.

## Faz Sıralaması

Bu doküman kapsamındaki işler, [ROADMAP.md](../ROADMAP.md) içindeki ana Phase 1-20 sırasına **paralel bir track** olarak ilerler:

| Faz | Kapsam | Bağımlılık |
|---|---|---|
| **W1** | Showroom — statik tanıtım sayfası (mevcut placeholder'ın yerini alır) | Yok — hemen başlanabilir |
| **W2** | Login/Signup entegrasyonu (e-posta + Google OAuth) | Phase 5 (Authentication) |
| **W3** | Web Panel — mobil ile feature parity | Phase 9+ (ilgili modüllerin API'leri hazır oldukça kademeli) |
| **W4** | Mobil showcase görsellerinin ve APK indirme butonunun showroom'a eklenmesi | Sprint 8 / MVP release (ilk APK release'i ile birlikte) |

> W1, backend'den bağımsız olduğu için MVP'nin geri kalanını beklemeden başlanabilir; sunucu tarafı zaten hazır (bkz. [deploy/README.md](../deploy/README.md)).
