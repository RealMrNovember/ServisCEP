# Web ve Mobil Özellik Eşitliği

Hedef: mobilde yapılabilen her şey web panelinden de yapılabilsin.
Cihaza özgü olanlar (kamera, telefon rehberi) bunun dışında.

Envanter 26 Ağustos 2026'da çıkarıldı.

## Web'de olup mobilde olmayan

| Özellik | Not |
|---|---|
| **Garantiler** | Web'de tam kaynak var, mobilde hiç karşılığı yok. Mobil tarafa eklenmeli mi, ayrıca karar verilecek. |

## Mobilde olup web'de olmayan — öncelik sırasıyla

### 1. Belge PDF'i üretimi

Web'den teklif ve proforma **oluşturulabiliyor** ama belge **üretilemiyor**.
Teklifin varlık sebebi müşteriye gönderilen o belge; onsuz web tarafı
yarım kalıyor.

PDF motoru şu an yalnızca mobilde (Flutter `pdf` paketi). Web için ayrı
bir üretici gerekiyor ve iki motorun **aynı belgeyi** üretmesi şart —
aksi halde aynı teklif iki farklı görünümde çıkar.

### 2. Cari hesap ve tahsilat

`CustomerResource` altında hiç ilişki yöneticisi yok: bakiye, hareketler
ve tahsilat web'den görülemiyor, girilemiyor. Ofisin asıl işi para takibi
olduğu için bu, PDF'ten sonra en büyük eksik.

### 3. İş detayı: fotoğraf, imza, tamamlama

Web'in iş formu düz CRUD (`customer_id`, `title`, `status`, fiyat
alanları). Şunlar yok:

- Sahada çekilen fotoğrafların görüntülenmesi
- Alınan imzanın görüntülenmesi
- "Tamamla ve ücret al" akışı (cari hesaba borç yazan)

Fotoğraf ÇEKMEK web'de anlamsız ama GÖRMEK çok değerli: ofis sahayı
ancak böyle görüyor.

### 4. Servis talepleri

Web'de hiç yok. Talep alma ve işe çevirme akışı yalnızca mobilde.

### 5. İş türleri

Mobilde ayarlardan yönetiliyor, web'de karşılığı yok.

### 6. Senkron çakışmaları

Çakışmayı mobil senkronu üretiyor ama ofisten çözülemiyor. Çakışmayı
çözecek kişi genelde ofiste olduğu için sıralamada yukarı çekilebilir.

## Bilinçli olarak web'e taşınmayacaklar

| Özellik | Sebep |
|---|---|
| Barkod tarama | Kamera gerektiriyor |
| Telefon rehberinden müşteri ekleme | Cihaz rehberi |
| Fotoğraf ÇEKME | Kamera — görüntüleme ayrı, o gerekli |
| Bildirim ayarları | Cihaza özel hatırlatma süresi; web'de karşılığı yok |
| Senkron durumu ekranı | Web zaten sunucunun kendisi; eşitlenecek bir şey yok |

## Dikkat

Mobil ve web aynı hesabı iki ayrı yerde yapmamalı. Bu proje bunu bir kez
yaşadı: abonelik süresi hesabı iki yerde ayrı yazıldığı için birbirinden
saptı ve `SubscriptionService` ile tek kaynağa toplandı. Belge toplamı da
aynı riski taşıyor — `CalculatesDocumentTotal` iki ayrı dosyada duruyor
(API ve Filament) ve ikisi elle eşit tutuluyor.
