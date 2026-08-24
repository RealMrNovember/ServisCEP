# Değişiklik Günlüğü

Bu dosya **kullanıcıya görünen** sürüm notlarının tek kaynağıdır.

Her `## vX.Y.Z` bölümünün içeriği, o sürüm etiketlendiğinde CI tarafından
otomatik olarak alınıp **Google Play "Yenilikler"** alanına yazılır
(bkz. [.github/workflows/release.yml](.github/workflows/release.yml)).

Kurallar:

- Bölüm başlığı tam olarak `## vX.Y.Z` biçiminde olmalı — tag ile birebir aynı.
- İçerik **500 karakteri geçemez** (Play Store sınırı). CI aşarsa sürümü durdurur.
- Metin **kullanıcıya** yazılır: teknik terim değil, ne kazandığını anlat.
  ("SyncService outbox'a job_photo kuyruğu ekler" değil → "Sahada çektiğiniz
  fotoğraflar artık ofisten görülebiliyor".)
- Bölüm yoksa veya boşsa CI sürümü **yayınlamaz** — not yazmak zorunludur.

---

## v0.6.0

Yenilikler:
• Personel ekleyin: çalışanlarınıza kendi hesaplarını açın ve yetkilerini belirleyin.
• Teknisyen rolü işletmenizin gelir, gider ve cari bilgilerini göremez.
• Cari hesap artık ofisle tam eşitleniyor; telefondaki ve paneldeki bakiye her zaman aynı.
• Aynı tahsilatın bakiyeye iki kez yansıyabildiği bir hata giderildi.

## v0.5.0

Yenilikler:
• Bildirimler: Abonelik onayı ve süre hatırlatmaları artık uygulama kapalıyken de telefonunuza geliyor.
• Şirket ayarları: Ünvan, işletme türü ve IBAN'ı uygulamadan düzenleyin. IBAN belgelerinizde görünür.
• İş türleri: Kendi türlerinizi ekleyin, iş oluştururken öneri olarak çıksın.
• Hatırlatma süresini seçin (kapalı, 15, 30, 60 veya 120 dakika).
• Menüde yüklü sürüm numarası gösteriliyor.

## v0.4.1

Yenilikler:
• Ofiste silinen müşteriler artık telefonunuzda da siliniyor.
• Aynı kaydı hem telefondan hem ofisten değiştirdiğinizde, hangi halin kalacağını uygulamadan seçebiliyorsunuz.
• Müşteri eklerken telefon rehberinizden kişi seçebilirsiniz.
• Müşteri kartına vergi levhası ekleyebilirsiniz — kamerayla tarayın, yeter.
• Menüde yüklü sürüm numarası gösteriliyor.

## v0.4.0

Yenilikler:
• Sahada çektiğiniz iş fotoğrafları, imzalar ve notlar artık ofisten de görülebiliyor.
• Uygulamayı ilk açtığınızda kısa bir tanıtım akışı sizi karşılıyor.

## v0.3.3

Yenilikler:
• Abonelik süresi dolduğunda uygulama sizi nazikçe bilgilendiriyor; kaydettiğiniz veriler kaybolmuyor, abonelik yenilenince eşitleniyor.

## v0.3.2

Yenilikler:
• Telefondan oluşturduğunuz talep, teklif, proforma ve tahsilatlar artık ofis paneline de akıyor.
• Talepten işe dönüştürme, internet gelince otomatik eşitleniyor.

## v0.3.1

Yenilikler:
• Uygulamanın adı TeknikCEP olarak değişti. İşlevlerde bir değişiklik yok.
