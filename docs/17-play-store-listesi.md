# 17 — Google Play Console: Kopyala-Yapıştır Referansı

> Bu doküman, Play Console'daki "Uygulamanızın kurulumunu tamamlayın" adımlarında
> doğrudan kopyalayıp yapıştırabileceğin metinleri içerir. Veri Güvenliği ve
> İçerik Derecelendirmesi gibi formlar senin adına gönderilen **beyanlardır** —
> Claude bunları senin yerine Play Console'a girmez, yalnızca taslak metni
> hazırlar; gönderme işlemini sen yaparsın.

## 1. Oturum açma bilgileri (App access)

Play Console'da "Uygulama kısıtlı, tüm işlevlere erişim için giriş gerekiyor"
seçeneğini işaretle ve açıklama kutusuna şunu yapıştır:

```
Uygulama açıldığında giriş ekranı gelir. Hesap oluşturmak ücretsizdir ve
anında tamamlanır, e-posta doğrulaması veya onay beklemez:

1. "Kayıt Ol" butonuna dokunun.
2. Aşağıdaki bilgileri girin:
   - Şirket adı: Play Review Test
   - İşletme türü: Elektrik (herhangi biri seçilebilir)
   - Ad Soyad: Play Reviewer
   - E-posta: playreview@serviscep.test
   - Şifre: PlayReview2026!
3. "Hesap Oluştur" butonuna dokunduğunuzda doğrudan uygulamaya giriş
   yapılır.

Alternatif: giriş ekranındaki "Google ile Devam Et" seçeneğiyle kendi
Google hesabınızla da anında giriş yapabilirsiniz — ek onay gerekmez.
```

> Not: Hesap tamamen cihaz-yerel (offline-first) olarak oluşturulur; e-posta
> gerçek bir gönderim yapılmaz, format kontrolü dışında bir doğrulama yoktur.

## 2. Reklam

**"Hayır, uygulamamda reklam yok."** — seç.

## 3. İçerik derecelendirme (IARC anketi)

Anket sorularının tamamına (şiddet, cinsellik, kumar, madde kullanımı, kaba
dil, korkutucu içerik) **"Hayır"** cevabı ver. Beklenen sonuç: **Herkes / 3+**.
Kategori: **İş uygulaması / Üretkenlik**.

## 4. Hedef kitle ve içerik

- Hedef yaş aralığı: **18 yaş üstü / genel işletme kullanıcıları** (çocuklara
  yönelik değil).
- "Uygulamanız çocukların ilgisini çekebilir mi?" → **Hayır**.

## 5. Veri güvenliği (Data safety) — taslak cevaplar

> ⚠️ Bu formu Play Console'un kendi arayüzünden adım adım dolduracaksın.
> Aşağıdaki tablo, her adımda hangi seçeneği işaretleyeceğini gösterir.

**Veri toplama/paylaşma genel:**
- "Uygulamanız veri topluyor mu?" → **Evet**
- "Uygulamanız herhangi bir veriyi üçüncü taraflarla paylaşıyor mu?" → **Hayır**

**Toplanan veri türleri:**

| Kategori | Alan | Toplanıyor mu | Amaç | Paylaşılıyor mu |
|---|---|---|---|---|
| Kişisel bilgiler | Ad Soyad | Evet | Uygulama işlevi (hesap + müşteri kaydı) | Hayır |
| Kişisel bilgiler | E-posta adresi | Evet | Hesap oluşturma/giriş | Hayır |
| Kişisel bilgiler | Telefon numarası | Evet | Uygulama işlevi (müşteri kaydı) | Hayır |
| Kişisel bilgiler | Adres | Evet | Uygulama işlevi (müşteri/iş adresi) | Hayır |
| Finansal bilgiler | Diğer finansal bilgiler | Evet | Uygulama işlevi (teklif/tahsilat/cari hesap tutarları) | Hayır |
| Fotoğraflar ve videolar | Fotoğraflar | Evet | Uygulama işlevi (iş fotoğrafları, dijital imza) | Hayır |

**Güvenlik uygulamaları:**
- "Veriler aktarım sırasında şifreleniyor mu?" → **Evet** (Google Sign-In /
  güncelleme kontrolü HTTPS üzerinden; müşteri verileri şu an yalnızca
  cihazda işleniyor, sunucuya iletilmiyor)
- "Kullanıcılar verilerinin silinmesini talep edebilir mi?" → **Evet**
  (uygulama içi silme + `info@cicibyte.com` üzerinden talep)
- "Bu, Play'in Aile Politikasına uygun mu?" → uygulamaya göre otomatik

> Not: Backend senkronizasyonu (Phase 17) devreye girdiğinde bu form
> güncellenmeli — o noktada veriler sunucuya da iletilecek.

## 6. Resmi kurum uygulamaları / Finans / Sağlık

- Resmi kurum uygulaması mı? → **Hayır**
- Finansal hizmet sunuyor mu? (kredi, yatırım, kripto, ödeme işleme) → **Hayır**
  — uygulama yalnızca işletmenin **kendi** teklif/tahsilat/cari hesap
  kayıtlarını tutar, üçüncü taraflara finansal hizmet sunmaz veya ödeme
  işlemi gerçekleştirmez.
- Sağlık uygulaması mı? → **Hayır**

## 7. Kategori ve iletişim

- Kategori: **İş (Business)**
- İletişim e-postası: `info@cicibyte.com`
- Web sitesi: `https://serviscep.cicibyte.com`
- Gizlilik politikası: `https://serviscep.cicibyte.com/privacy`

## 8. Mağaza girişi (Store listing)

**Kısa açıklama** (max 80 karakter):

```
Saha teknik servis işletmeleri için mobil-first iş yönetim uygulaması
```

**Tam açıklama** (max 4000 karakter):

```
TeknikCEP, saha teknik servis işletmelerinin (elektrik, kamera sistemleri,
bilgisayar/beyaz eşya tamiri ve benzeri) müşteri, iş, teklif/proforma ve
finans süreçlerini tek bir yerden yönetmesi için tasarlanmış mobil-first,
offline-first bir işletme yönetim platformudur.

ÖNE ÇIKAN ÖZELLİKLER

• Müşteri Yönetimi — yetkili adı/firma adı, iletişim bilgileri, adres,
  vergi bilgisi ve cari hesap ekstresi tek ekranda.

• İş / Servis Takibi — randevu planlama, durum akışı (talep, planlandı,
  devam ediyor, tamamlandı), teknisyen ataması, öncelik seviyeleri.

• Servis Formu — kategorili fotoğraf ekleme (öncesi/arıza/montaj/sonrası)
  ve dijital imza toplama.

• Stok & Barkod — ürün kataloğu, kamera ile barkod okuma, stok durumu
  uygulama içi renkli rozetlerle gösterilir; teklif/proforma kalemleri
  doğrudan stoktan seçilebilir.

• Teklif & Proforma — kurumsal görünümlü PDF belgeler, WhatsApp/Android
  paylaşım menüsüyle tek dokunuşla müşteriye gönderim.

• Cari Hesap — özet bakiye değil, tam kronolojik borç/alacak hareket
  dökümü.

• Finans Paneli — gelir/gider takibi, tahsilat kaydı, günlük özet.

• Takvim — aylık görünüm ve günlük iş listesi.

• Yerel Hatırlatmalar — randevu saatinden önce cihaz üzerinde bildirim,
  internet gerektirmez.

• Offline-First Mimari — İnternet olmadan da tam işlevsel çalışır;
  tüm veriler önce cihazda, güvenli şekilde saklanır.

Bu belgeler resmi e-fatura veya resmi elektronik imza yerine geçmez;
TeknikCEP bir işletme ve teknik servis yönetim platformudur, muhasebe
yazılımı değildir.

TeknikCEP, Cicibyte Teknoloji (cicibyte.com) tarafından geliştirilmiştir.
```

**Grafikler:**
- Uygulama ikonu: `assets/branding/icon-512.png` (hazır)
- Feature graphic (1024×500): `assets/branding/feature_graphic.png` (hazır)
- Telefon ekran görüntüleri: gerçek cihazdan alınması gerekiyor (bkz.
  ROADMAP.md § W4)
