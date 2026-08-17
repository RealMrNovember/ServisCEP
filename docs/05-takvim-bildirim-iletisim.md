# 05 — Takvim, Bildirim ve İletişim

> Kaynak: orijinal spesifikasyon §27–§30, §48–§49.

## 1. Randevu / Takvim

Takvim ekranı, günlere göre iş yoğunluğunu özetler:

```
AĞUSTOS 2026

18 Salı        3 İş
19 Çarşamba    2 İş
20 Perşembe    4 İş
```

Her iş satırında şu bilgiler gösterilmelidir: **Saat · Müşteri · Adres · İş tipi · Öncelik**

## 2. Harita

Müşteri adres kartında bir **"Haritada Aç"** butonu bulunmalıdır (cihazın varsayılan harita uygulamasını açar).

**Gelecek geliştirme:** "Bugünkü İşler → Harita" görünümü — günün tüm randevularını tek haritada, rota mantığıyla gösterme.

## 3. Hatırlatmalar

Sistem aşağıdaki hatırlatma türlerini desteklemelidir:

- Servis randevusu
- Tahsilat
- Teklif takibi
- Garanti bitişi
- Periyodik bakım
- Müşteri geri dönüşü
- Planlanan iş

## 4. Bildirimler

Örnek bildirim türleri (kullanıcıya doğal dilde, aksiyon odaklı sunulur):

```
🔔 Yarın 10:00'da ABC Market servisi var.
💰 Mehmet Kaya'dan 3.500 TL tahsilat bekliyor.
📄 XYZ teklifinin süresi yarın doluyor.
🛠️ ABC Market'in bakım zamanı geldi.
```

> ⚠️ **Zorunlu gereksinim:** Bu bildirimler yalnızca uygulama içi (in-app) değil, **push notification** olarak da iletilmelidir — kullanıcı uygulamayı açık tutmasa dahi hatırlatmayı almalıdır. Teknik mekanizma (FCM, cihaz kaydı, arka plan job) için bkz. [06 — Teknik Mimari § Push Notification](06-teknik-mimari.md#push-notification-zorunlu).

## 5. WhatsApp Paylaşımı

> **MVP'de doğrudan WhatsApp Business API entegrasyonuna gerek yoktur.**

Bunun yerine **Android'in yerleşik Share (paylaşım) mekanizması** kullanılmalıdır:

```
Servis Formu PDF → Paylaş → WhatsApp
```

### Mesaj Şablonu

```
Merhaba Ahmet Bey,

Bugün gerçekleştirdiğimiz servis işlemine ait
servis formunuzu ekte iletiyorum.

Teşekkür ederiz.
```

Bu yaklaşım, karmaşık bir API entegrasyonu olmadan MVP'nin temel iletişim ihtiyacını çözer. WhatsApp Business API entegrasyonu V3 roadmap kapsamındadır (bkz. [ROADMAP.md](../ROADMAP.md)).

## 6. Garanti ve Bakım (V2)

V2 kapsamında her iş için aşağıdaki alanlar tanımlanabilmelidir:

- Garanti başlangıç tarihi
- Garanti bitiş tarihi
- Garanti süresi
- Bakım periyodu

**Örnek:** *"Kamera sistemi 12 ay garantili."*

Sistem, garanti bitiş tarihinden önce otomatik bildirim gönderebilmelidir — bu, hem müşteri memnuniyeti hem de tekrar satış (bakım sözleşmesi) fırsatı yaratır.
