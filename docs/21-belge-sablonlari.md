# Belge Kimliği ve Şablonlar

Kullanıcı teklif ve proformasını kendi işletmesine benzeyecek şekilde
üretebilmeli. Herkesin aynı taslakla belge göndermesi, belgeyi gönderenin
kimliğini siliyor: bir elektrikçinin teklifi ile bir güvenlik sistemi
firmasının teklifi aynı görünmek zorunda değil.

Bu, tek bir "şablon seçici" değil **iki eksenli bir kimlik sistemi**:

| Eksen | Ne belirler | Kaç seçenek |
|---|---|---|
| **Yerleşim** | Blokların dizilişi, başlığın yeri, tablonun biçimi | 4 şablon |
| **Görünüm** | Renk paleti, yoğunluk, tipografi çifti, tablo sıklığı, logo yerleşimi | 6 palet × 3 yoğunluk × 3 tipografi |

İki eksen çarpım yapıyor: 4 yerleşim × 6 palet × 3 yoğunluk × 3 tipografi
= 216 farklı belge görünümü. Hepsinin okunaklılığı garanti, çünkü
seçenekler serbest değil **curated**.

---

## 1. Şablon VERİdir, kod değildir

Belge üreticisi bugün yalnızca mobilde (`pdf_service.dart`); web panelde
belge üretimi hiç yok (bkz. ROADMAP → W3). Şablonlar iki motora ayrı
ayrı kodlanırsa aynı teklif iki farklı görünümde çıkar. Bu proje aynı
hatayı iki kez yaşadı — abonelik süresi hesabı ve belge toplamı
(`CalculatesDocumentTotal`) — ve ikisi de tekilleştirilerek düzeltildi.

Belge zaten adlandırılmış bloklardan diziliyor:

```
_titleBand _letterhead _partyBox _intro
_itemsTable _totalsPanel _bottomBlocks _signatureBoxes
```

Yeni motor yazılmıyor; bloklara varyant ekleniyor ve varyant seçimi
veriden geliyor.

---

## 2. Renk paletleri

Kullanıcı **hazır paletlerden birini seçer**. Serbest renk girişi yok.

### Neden serbest renk yok

Serbest hex seçimi profesyonel belge üretmez:

- Neon yeşil zemin üzerine beyaz antet yazısı **okunmaz**.
- Açık sarı vurgu çizgisi beyaz kâğıtta **kaybolur**.
- Koyu lacivert zebra dolgusu, üzerindeki siyah yazıyı **yutar**.

Bu varsayım değil, bu projede yaşanmış bir şey: uygulamanın kendi vurgu
rengi `#3B82F6`, beyaz yazıyla 3.68:1 kontrast veriyor ve WCAG AA'yı
geçmiyor. Bu yüzden palette **iki ayrı** token var (`accent` 3:1
gerektiren öğeler için, `accentSolid` beyaz yazı taşıyan dolgular için).

Serbest renk seçtirmek, bu tuzağı her kullanıcıya devretmek olurdu.
Kullanıcı renk teorisi bilmek zorunda değil; biz zaten biliyoruz.

### Palet nedir

Bir palet, elle seçilmiş ve kontrastı **bir kez doğrulanmış** dört tondan
oluşur:

| Ton | Kullanım | Eşik |
|---|---|---|
| `guclu` | Dolu antet bloğu, tablo başlığı — üzerinde BEYAZ yazı | beyazla ≥ 4.5:1 |
| `vurgu` | İnce çizgiler, başlık şeridi, küçük işaretler | beyazla ≥ 3:1 |
| `yumusak` | Zebra satırı, yumuşak paneller — üzerinde KOYU yazı | mürekkeple ≥ 7:1 |
| `cizgi` | Tablo ve kutu kenarları | görünür olacak kadar |

Mürekkep ve soluk gri **her palette nötr ve aynıdır**. Gövde metni asla
renkli olmaz: renkli gövde metni amatör görünür ve okumayı zorlaştırır.

### Palet listesi

| Kod | Ad | Karakter |
|---|---|---|
| `lacivert` | Lacivert | Bugünkü renk. Güvenilir, nötr, her sektöre uyar. Varsayılan. |
| `antrasit` | Antrasit | Renksiz denecek kadar ağırbaşlı; koyu gri tonları. |
| `bordo` | Bordo | Sıcak ve kurumsal; muhasebe/danışmanlık hissi. |
| `orman` | Orman Yeşili | Teknik servis ve bakım işlerinde yaygın. |
| `bakir` | Bakır | Sıcak turuncu-kahve; zanaat/ustalık çağrışımı. |
| `petrol` | Petrol Mavisi | Soğuk yeşil-mavi; mühendislik hissi. |

Yeni palet eklemek tek satırlık bir kayıt — ama kontrast testinden
geçmeden kataloğa giremez.

### Yoğunluk

Rengin belgede ne kadar yer kapladığı ayrı bir ayar:

| Yoğunluk | Belgede |
|---|---|
| `sade` | Yalnızca ince başlık şeridi ve tablo çizgileri renkli |
| `dengeli` | + tablo başlığı ve toplamlar paneli renkli zeminli |
| `belirgin` | + dolu antet bloğu, ters renkte firma adı |

Altı palet × üç yoğunluk = on sekiz farklı renk karakteri; hepsi
okunaklılığı garanti edilmiş.

---

## 3. Tipografi

Üç curated çift. Serbest yazı tipi yüklemesi **yok**: PDF'e gömülmeyen
bir yazı tipi karşı tarafta bambaşka görünür ve gömülen her yazı tipi
belge boyutunu büyütür. Ayrıca ₺ glifi olmayan bir yazı tipi seçilirse
her tutarda kutucuk çıkar — bu da bu projede yaşandı (JetBrains Mono).

| Çift | Karakter |
|---|---|
| `modern` | Archivo + Barlow — uygulamanın kendi dili, varsayılan |
| `kurumsal` | Serif başlık + nötr gövde — resmi, muhasebe/hukuk hissi |
| `teknik` | Dar grotesk — uzun kalem listelerinde daha çok satır sığar |

Her çiftin ₺ desteği **testle kilitlenir**; yedeksiz bir yazı tipi
kataloğa giremez.

---

## 4. Yerleşim şablonları

| Kod | Ad | Karakter |
|---|---|---|
| `klasik` | Klasik | Bugünkü tasarım. Üstte şerit, ortalanmış başlık. Varsayılan ve geri düşüş hedefi. |
| `sade` | Sade | Başlık solda ve büyük, ince çizgili tablo, bol beyaz alan. |
| `kurumsal` | Kurumsal | Logo öne çıkar, antet dolu blok, künye bloğun içinde. |
| `kompakt` | Kompakt | Dar satırlar, uzun listeler tek sayfaya sığsın. İmza kutuları yok. |

Dördü de **aynı bilgiyi** taşır; hiçbir şablon bir alanı gizlemez. Bir
şablonun daha az bilgi göstermesi, kullanıcının farkında olmadan eksik
belge göndermesi demek olurdu.

---

## 5. Belge kimliği tek yerde tanımlanır

```dart
class BelgeKimligi {
  final String yerlesim;        // 'klasik' | 'sade' | 'kurumsal' | 'kompakt'
  final String palet;           // 'lacivert' | 'antrasit' | ...
  final Yogunluk yogunluk;      // sade | dengeli | belirgin
  final String tipografi;       // 'modern' | 'kurumsal' | 'teknik'
  final LogoYeri logoYeri;      // sol | orta | antetIcinde
  final TabloSikligi tablo;     // ferah | normal | siki
}
```

Bu kimlik **şirket düzeyinde** tutulur ve teklif, proforma, servis formu,
cari ekstre — hepsine uygulanır. Belgeler arası tutarlılık, belge başına
rastgele seçimden daha profesyonel görünür.

Tek belgelik istisna yine mümkün: `quotes.template_code` /
`proformas.template_code` yalnızca **yerleşimi** ezer, rengi ve
tipografiyi değil.

---

## 6. Seçim nerede saklanır

| Alan | Yer | Anlamı |
|---|---|---|
| `companies.document_identity` (JSON) | Sunucu + mobil | Şirketin belge kimliği |
| `quotes/proformas.template_code` | Sunucu + mobil, nullable | Tek belgelik yerleşim istisnası |

Belge kaydedildiğinde **o anki kimlik belgeye yazılır** (kimliğin kendisi,
yalnızca kodu değil). Kullanıcı sonradan rengini değiştirdiğinde eski
belgeler görünüm değiştirmez — müşteriye gönderilmiş bir belgenin yeniden
üretildiğinde farklı çıkması kabul edilemez.

---

## 7. Çevrimdışı kısıtı

**Şablonlar, yazı tipleri ve palet uygulamayla birlikte gelir.**
Sunucudan indirilen bir şablon, internetsiz belge üretimini kırar;
uygulamanın temel vaadi bu.

Sunucu yalnızca *seçimi* taşır, içeriğini değil.

---

## 8. Bilinmeyen değer → sessizce varsayılana düş

Panelden yeni bir yerleşim ya da tipografi seçildiğinde, henüz
güncellememiş bir kullanıcıda o seçenek yoktur. Belge üretimi **hata
vermez**; bilinmeyen her alan tek tek varsayılanına düşer.

```dart
final yerlesim = _yerlesimler[kimlik.yerlesim] ?? _yerlesimler['klasik']!;
final tipo     = _tipografiler[kimlik.tipografi] ?? _tipografiler['modern']!;
```

Alternatif — hata vermek — kullanıcının belgesini hiç üretememesi
demekti; görünümün eski olması bundan kat kat iyidir.

---

## 9. Kullanıcı nasıl seçer

Seçim ekranında **gerçek bir belge önizlemesi** görünür ve her ayar
değiştiğinde tazelenir. Metin açıklama ("Sade: bol beyaz alan") kimseye
bir şey ifade etmiyor; kullanıcı belgesinin neye benzeyeceğini görmek
istiyor.

Önizleme **belge motorunun kendisinden** üretilir — elle çizilmiş bir
örnek, tasarım değiştiğinde sessizce yalan söylemeye başlar. Küçük
görseller için mağaza ekran görüntülerinde kurulan koşumun aynısı
kullanılır (`test/store/`).

---

## 10. Testle kilitlenecekler

Bu sistem görsel olduğu için gözle kontrole bırakılamaz:

- **Kontrast**: kataloğa giren HER paletin dört tonunun da eşiğini
  tutturması. Yeni bir palet eklendiğinde test onu otomatik kapsar —
  gözle bakmaya gerek kalmaz.
- **₺ desteği**: kataloğa giren her yazı tipi çiftinin ₺ (U+20BA)
  glifini taşıması ya da yedeğinin olması.
- **Geri düşüş**: bilinmeyen yerlesim/tipografi/renk değerlerinde belge
  üretiminin hata vermeden tamamlanması.
- **Bilgi kaybı yok**: her yerleşimin aynı alan kümesini çizmesi.

---

## 11. Uygulama sırası

Her adım tek başına yayınlanabilir:

1. **Palet kataloğu + `klasik`'in paletten okuması.** Mevcut sabitler
   (`_accent`, `_accentSoft`, `_line`, `_zebra`) zaten bu dört tonun
   karşılığı; ilk adım onları kayda taşımak. Tek başına en büyük görsel
   farkı üretir, şablon altyapısını beklemez.
2. **Yoğunluk** (sade/dengeli/belirgin) — yalnızca mevcut blokların renk
   kullanımını değiştirir.
3. **`BelgeKimligi` kaydı** — davranış değişmez, mevcut sabitler kayda
   taşınır.
4. **`sade` ve `kompakt` yerleşimleri** — yalnızca varyant, yeni blok yok.
5. **`kurumsal` yerleşimi** — tek yeni blok varyantı (dolu antet).
6. **Tipografi çiftleri.**
7. **Seçim arayüzü + canlı önizleme.**
8. **Paket kademesi**: ücretsiz pakette varsayılan palet + `klasik`; ücretlide
   tamamı. Belge altbilgisindeki "TeknikCEP ile hazırlandı" ibaresiyle
   birlikte tek bir yükseltme sebebi oluşturur. Kısıt **sunucuda**
   uygulanır; istemci yalnızca kilidi gösterir (bkz. docs/09).

42 ekranlık yeniden düzenle aynı sürüme sokulmaz — ikisi birden riske
atılmış olur.
