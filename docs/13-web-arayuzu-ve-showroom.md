# 13 — Web Arayüzü ve Showroom

> Bu doküman, orijinal spesifikasyonun ötesinde geliştirme sürecinde eklenen bir gereksinimdir (bkz. [ROADMAP.md § Ek Gereksinimler](../ROADMAP.md#ek-gereksinimler-sonradan-eklenen)). Orijinal spesifikasyon web paneli yalnızca V2 kapsamında öngörüyordu (§58); bu doküman kapsamı iki parçaya ayırarak netleştirir: **herkese açık showroom** (erken başlanabilir) ve **web panel** (API'ler hazır olunca).

ServisCEP'in web varlığı iki ayrı amaca hizmet eder:

1. **Showroom (Tanıtım Sitesi)** — `serviscep.cicibyte.com` üzerinde herkese açık, ürünü tanıtan, giriş/kayıt akışına yönlendiren profesyonel bir açılış sayfası.
2. **Web Panel** — mobil uygulamayla **aynı Laravel API'yi** tüketen, tarayıcı üzerinden tam işlevsel bir yönetim arayüzü (masaüstünden çalışmak isteyen kullanıcılar için).

Bu iki parça aynı domain altında, kimlik doğrulama durumuna göre ayrışır: giriş yapmamış ziyaretçi showroom'u görür, giriş yapmış kullanıcı panele yönlendirilir.

## 1. Showroom (Tanıtım Sitesi)

### Amaç

Ziyaretçiye ürünü profesyonelce tanıtmak ve giriş/kayıt akışına yönlendirmek.

### Kapsam

- Hero bölümü — ürün vaadi (bkz. [01 — Vizyon ve Felsefe](01-vizyon-ve-felsefe.md))
- Özellik tanıtımı (müşteri yönetimi, servis formu, teklif/proforma, finans, offline-first)
- **Mobil uygulama ekran görüntüleri / showcase** — mobil UI tamamlandığında eklenir (bkz. §4 aşağıda)
- **Giriş (Login) ve Kayıt (Signup)** butonları — zorunlu, sayfanın her yerinden erişilebilir
- İletişim/CTA alanı

### Kimlik Doğrulama Giriş Noktası

Showroom'daki Login/Signup, [09 — Güvenlik ve Yetkilendirme § Kimlik Doğrulama Yöntemleri](09-guvenlik-ve-yetkilendirme.md#0-kimlik-doğrulama-yöntemleri) içinde tanımlanan akışı kullanır (e-posta+parola ve Google OAuth).

## 2. Web Panel

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

## 3. Kimlik Doğrulama ve Yetkilendirme

Web panel, [09 — Güvenlik ve Yetkilendirme](09-guvenlik-ve-yetkilendirme.md) içindeki rol/yetki modelini birebir uygular — mobilde geçerli olan (`OWNER`, ileride `ADMIN`/`TECHNICIAN`/`ACCOUNTING`/`VIEWER`) kısıtlamalar web tarafında da sunucu düzeyinde zorunlu kılınır. Web arayüzünün varlığı, [11 — Geliştirme Prensipleri](11-gelistirme-prensipleri.md) içindeki *"yetkilendirme yalnızca frontend'e bırakılmaz"* kuralını daha da kritik hale getirir — iki farklı istemci (mobil + web) aynı sunucu taraflı policy'lere güvenmelidir.

## 4. Mobil Showcase Entegrasyonu

Mobil uygulamanın modern arayüzü tamamlandığında (Sprint 8 / MVP release civarı, bkz. [ROADMAP.md](../ROADMAP.md)), gerçek ekran görüntüleri ve/veya kısa ekran kayıtları showroom sayfasına eklenmelidir. Bu adım, showroom'un ilk sürümünde **placeholder/mockup görsellerle** başlayıp mobil UI olgunlaştıkça gerçek görsellerle güncellenmesi şeklinde ilerler.

## Faz Sıralaması

Bu doküman kapsamındaki işler, [ROADMAP.md](../ROADMAP.md) içindeki ana Phase 1-20 sırasına **paralel bir track** olarak ilerler:

| Faz | Kapsam | Bağımlılık |
|---|---|---|
| **W1** | Showroom — statik tanıtım sayfası (mevcut placeholder'ın yerini alır) | Yok — hemen başlanabilir |
| **W2** | Login/Signup entegrasyonu (e-posta + Google OAuth) | Phase 5 (Authentication) |
| **W3** | Web Panel — mobil ile feature parity | Phase 9+ (ilgili modüllerin API'leri hazır oldukça kademeli) |
| **W4** | Mobil showcase görsellerinin showroom'a eklenmesi | Sprint 8 / MVP release |

> W1, backend'den bağımsız olduğu için MVP'nin geri kalanını beklemeden başlanabilir; sunucu tarafı zaten hazır (bkz. [deploy/README.md](../deploy/README.md)).
