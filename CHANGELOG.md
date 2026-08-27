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

## v0.8.0

Yenilikler:
• Uygulama baştan aşağı yenilendi: 38 ekranın tamamı yeni tasarımda.
• Ana Sayfa günü tek bakışta gösteriyor; sıradaki işi aramak ve yol tarifi almak tek dokunuş.
• Teklif formu dört adıma bölündü.
• İş tamamlama artık kontrol listesi, tahsilat ve ödeme türü içeriyor.
• Açık/koyu tema seçimi geldi; servis talebini artık reddedebiliyorsunuz.
• Cari hesapta borç, tahsilat ve kalan bakiye bir arada.
• Güncelleme uyarısı işinizi kesmiyor; kapatılabilir bir şerit oldu.

## v0.7.8

Yenilikler:
• Çevrimdışı kaydettikleriniz artık uygulama kapalıyken de gönderiliyor; internet gelince kendiliğinden eşitleniyor.
• Yeni kayıt oluşturduğunuzda eşitleme hemen başlıyor.
• Gönderilemeyen kayıtlar tekrar deneniyor; olmazsa senkron ekranından tek dokunuşla yeniden gönderin.
• Oturumunuz düşse de bekleyen kayıtlar korunuyor.
• Geri Bildirim eklendi: öneri ve sorunlarınızı yazın, yanıtlayınca bildirim gelir.

## v0.7.7

Yenilikler:
• Uygulama simgesi yenilendi.
• "Ödemelerim" ekranı eklendi: geçmiş ödemeleriniz tarih, tutar ve durumuyla listeleniyor. Onay bekleyenler en üstte ayrı duruyor.
• Ödeme bildiriminiz onaylanmadığında artık haberdar oluyorsunuz; gerekçe hem bildirimde hem kaydın altında yazıyor.
• Onay sırasında size yazılan not da uygulamada görünüyor.

## v0.7.6

Yenilikler:
• Alt menü yenilendi: seçili sekme artık yumuşak bir vurguyla belirtiliyor ve sekme değiştirdiğinizde göstergeci kayarak takip ediyor.
• Açık temada alt menü de açık renkte; önceden koyu kalıyordu.
• İşler, Müşteriler ve Belgeler ekranlarının sağ üstünde bekleyen kayıt sayısı görünüyor. Dokununca eşitleme durumuna gidiyor.
• Sorun bildirdiğinizde hangi sürümü kullandığınızı size sormamıza gerek kalmıyor; destek tarafı bunu görebiliyor.

## v0.7.5

Yenilikler:
• Bağlantı durumu ekranın üstünde görünüyor: internet yokken kaç kaydın cihazda beklediğini yazıyor. Kaydırarak kapatabilirsiniz.
• "Gönderiliyor" yazan yerler doğruyu söylüyor: gerçekten gönderilirken "eşitleniyor", sırasını beklerken "bekliyor".
• Teklifte kalemlerin KDV oranı farklıysa belge artık tek bir oran yazmıyor.
• Ödeme bilgisi bloğu her belgede yer alıyor.
• Aksilikte teknik hata metni yerine anlaşılır bir açıklama ve kayıtlarınızın güvende olduğu bilgisi çıkıyor.

## v0.7.4

Yenilikler:
• Uygulamanın rengi ve yazı tipleri yenilendi; koyu tema bu kez baştan koyu için tasarlandı, güneş altında okunaklılık gözetildi.
• Logo yükleme yenilendi: kırpma oranını ve zemini (şeffaf, beyaz, koyu) siz seçiyorsunuz. Beyaz logolar artık kaybolmuyor.
• Teklif belgesinde logonuz kendi oranında basılıyor; yatay logolar küçücük çıkmıyor.
• İskonto sütunu belgede yalnızca gerçekten iskonto varsa görünüyor.
• Yeni müşteri oluşturduğunuzda listeye seçili olarak dönüyor.

## v0.7.3

Yenilikler:
• 0.7.2'de uygulamanın sunucuya hiç bağlanamamasına yol açan hata giderildi. Abonelik, senkron ve tüm sunucu işlemleri yeniden çalışıyor.
• Senkron durumu ekranı artık doğruyu söylüyor: sunucuya ulaşılamadığında "eşitlendi" yazmıyor.
• Teklif oluştur düğmesi sessizce kapalı kalmıyor; eksik ne varsa adıyla söylüyor.

## v0.7.2

Yenilikler:
• Yeni sürüm çıktığında artık beklemeden haberdar oluyorsunuz; güncelleme bildirimi Play'in yayılmasını beklemiyor.
• Güncelleme penceresinde o sürümde nelerin değiştiği yazıyor.
• Çıkış yaptığınızda cihaz gerçekten çıkış yapıyor: bildirimler kesiliyor, oturum sunucuda da kapanıyor.

## v0.7.1

Yenilikler:
• Uygulamayı silip yeniden kurduktan sonra bazı cihazlarda hiç giriş yapılamamasına yol açan sorun giderildi.
• Bağlantı hatası artık sizi yanlışlıkla yeni hesap açma ekranına göndermiyor.
• Bir aksilik olduğunda hatanın gerçek sebebi ekranda yazıyor.
• Zayıf bağlantıda giriş daha sabırlı bekliyor.
• Tamamlanan işin ücreti iş listesinde görünüyor.

## v0.7.0

Yenilikler:
• Profesyonel teklif formu: logolu antet, müşteri bilgileri, kalem tablosu ve kaşe/imza alanlarıyla tek sayfalık kurumsal belge.
• Aynı formdan proforma fatura da düzenleyin; belge numarası kaldığı yerden devam eder.
• TL, dolar veya euro; "+KDV" ya da "KDV dahil" seçin, oranı siz belirleyin.
• Ödeme, teslim ve garanti için hazır ifadeler.
• Belgeyi WhatsApp veya e-postayla gönderin.
• Firma ve müşteri logonuzu ekleyip kırpın.
• Tamamlanan işin ücreti listede görünüyor.

## v0.6.1

Yenilikler:
• "Daha Fazla" menüsünde bir ekrandayken sekmeye tekrar bastığınızda artık menüye dönüyorsunuz.
• Ekibinize eklemek istediğiniz kişi daha önce kendi başına üye olduysa, uygulama artık ne yapmanız gerektiğini açıkça söylüyor.

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
