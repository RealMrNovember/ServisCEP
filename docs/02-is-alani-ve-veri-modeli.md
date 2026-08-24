# 02 — İş Alanı ve Veri Modeli (Domain Layer)

> Kaynak: orijinal spesifikasyon (giriş bölümü), §10–§13.

Bu doküman, TeknikCEP'in temel iş alanı (domain) kavramlarını tanımlar: **Müşteri**, **İş/Servis** ve **Talep**. Bu üç kavram, sistemin tüm diğer modüllerinin (belge, finans, takvim) üzerine kurulduğu temel varlıklardır.

## 1. Müşteri (Customer)

### Temel Alanlar

- Ad / Unvan
- Adres
- İl
- İlçe
- Vergi bilgileri
- Notlar
- Etiketler

### Müşteri Tipleri

| Tip | Açıklama |
|---|---|
| Bireysel | Gerçek kişi müşteri |
| Firma | Tüzel kişi / ticari işletme |
| Apartman | Apartman yönetimi |
| Site | Site yönetimi |
| Kamu | Kamu kurumu |
| Diğer | Sınıflandırılamayan müşteri tipleri |

### Müşteri Profili

Müşteri kaydı açıldığında aşağıdaki sekmeler/bölümler gösterilmelidir:

**Genel**
- İletişim bilgileri
- Adres
- Notlar

**Finans**
- Toplam iş tutarı
- Tahsil edilen tutar
- Bekleyen tutar
- Toplam borç (güncel bakiye — cari hesaptan türetilir)
- "Ekstre Görüntüle / PDF İndir" aksiyonu

> Bu özet rakamların arkasında tam bir **cari hesap** (kronolojik borç/alacak hareketleri + bakiye) bulunur — bkz. [15 — Cari Hesap](15-cari-hesap.md).

**İş Geçmişi**
- Müşteriye ait tüm servisler kronolojik sırayla listelenir.

**Belgeler**
- Teklifler
- Proformalar
- Servis formları
- Tahsilatlar
- Faturalar

**Fotoğraflar**
- Müşteriye bağlı tüm iş fotoğrafları tek noktadan görüntülenir.

> Detaylı belge tipleri için bkz. [03 — Servis ve Belge Yönetimi](03-servis-ve-belge-yonetimi.md).

## 2. İş / Servis Modülü (Job)

Her iş, benzersiz ve otomatik üretilmiş bir numaraya sahip olmalıdır.

```
Örnek:  SRV-2026-000142
```

> Numaralandırma kuralları için bkz. [03 — Servis ve Belge Yönetimi § Akıllı Numaralandırma](03-servis-ve-belge-yonetimi.md#akıllı-numaralandırma).

### İş Durumları (State Machine)

```
TALEP → PLANLANDI → DEVAM EDİYOR → TAMAMLANDI
                 ↘ BEKLEMEDE ↗
                 ↘ İPTAL
```

| Durum | Açıklama |
|---|---|
| `TALEP` | Henüz işe dönüştürülmemiş, ön kayıt |
| `PLANLANDI` | Randevu tarihi/teknisyen atanmış |
| `DEVAM EDİYOR` | Saha ekibi işi yürütüyor |
| `BEKLEMEDE` | Dış etken nedeniyle askıda (malzeme bekleniyor vb.) |
| `TAMAMLANDI` | İş bitmiş, servis formu düzenlenmiş |
| `İPTAL` | İş sonlandırılmış — **hard delete edilmez**, bkz. [09 § Veri Silme Prensibi](09-guvenlik-ve-yetkilendirme.md#veri-silme-prensibi) |

### İş Bilgileri (Alan Listesi)

- İş numarası
- Müşteri (ilişki)
- İş türü
- Başlık
- Açıklama
- Adres
- Randevu tarihi
- Başlangıç zamanı
- Bitiş zamanı
- Öncelik
- Durum
- Teknisyen (atanan kullanıcı)
- Tahmini fiyat
- Gerçek fiyat
- Notlar

## 3. İş Türleri (Job Types)

Sistem, aşağıdaki hazır iş türü kataloğu ile gelmelidir. Kullanıcı ayrıca **kendi özel iş türünü** oluşturabilmelidir — bu nedenle iş türleri sabit kodlanmış (hardcoded) bir enum değil, şirket bazlı yapılandırılabilir bir tablo olmalıdır.

**Elektrik**
Arıza · Tesisat · Aydınlatma · Priz · Sigorta · Kablo · Montaj · Bakım

**Güvenlik Sistemleri**
IP Kamera · Analog Kamera · DVR · NVR · Alarm · İnterkom · Access Control · Kamera bakımı · Kamera arızası · Kamera kurulumu

**Bilgisayar**
Format · Windows kurulumu · SSD değişimi · RAM değişimi · Donanım arızası · Yazılım kurulumu · Virüs temizleme · Bakım

**Diğer**
Network · Diğer (kullanıcı tanımlı)

## 4. Talep Modülü (Service Request)

Müşteriden gelen talepler, işlerden **ayrı bir varlık** olarak tutulur. Bu ayrım önemlidir: her talep bir işe dönüşmeyebilir (reddedilebilir, tekrarlanabilir, birleştirilebilir).

### Örnek Kayıt

```
TALEP #REQ-2026-00152

Müşteri:   ABC Market
Talep:     3 kamera görüntü vermiyor.
Öncelik:   Yüksek
Adres:     Kadıköy / İstanbul
Durum:     Bekliyor
```

### Talep → İş Dönüşümü

Bir talep, kullanıcı onayıyla doğrudan bir işe (job) dönüştürülebilmelidir. Dönüşüm sırasında talebin bağlamı (müşteri, açıklama, öncelik, adres) işe otomatik taşınmalıdır.

## Veri Modeli İlişkisi (Özet)

```
customer 1───N service_request
customer 1───N job
service_request 0..1───1 job   (bir talep en fazla bir işe dönüşür)
job 1───N job_notes / job_photos / job_materials / job_signatures
```

> Tam veritabanı şeması için bkz. [07 — API ve Veritabanı](07-api-ve-veritabani.md).
