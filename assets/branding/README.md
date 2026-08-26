# Marka Varlıkları

Tek kaynak: `mobile/assets/brand/teknikcep-b-plaka-appicon-512.svg`.

Uygulama simgesi, mağaza simgesi, favicon ve afiş hep bu dosyadan
türetilir. Aksi halde yüzeyler birbirinden sapar — bu bir kez yaşandı:
yeni marka işareti 0.7.7 ile uygulamaya girdi ama Play mağaza listesi
eskisiyle kaldı ve kullanıcı Play'de eski, telefonunda yeni logoyu
gördü.

## Üreticiler

| Betik | Ne üretir |
|---|---|
| `generate_assets.py` | İkon seti (16–512), `favicon.ico`, `play-store-icon.png` |
| `generate_feature_graphic.py` | `play-feature-graphic.png` (1024×500) |
| `generate_store_screenshots.py` | `store/*.png` — mağaza ekran görüntüleri |

Depo kökünden:

```bash
python assets/branding/generate_assets.py
```

`generate_feature_graphic.py` ve `generate_store_screenshots.py` ham
ekran görüntülerine ihtiyaç duyar; önce onları üret (aşağıya bak).

## Mağaza simgesi neden ayrı

Play köşe yuvarlamayı ve gölgeyi **kendisi** uygular ve saydamlık kabul
etmez. Hazır yuvarlatılmış bir ikon iki kez yuvarlatılmış görünür.
Bu yüzden `play-store-icon.png` aynı işaretten ama **köşesi
yuvarlatılmamış tam kare ve opak** olarak üretilir; web ikonları
(`icon-*.png`) yuvarlatılmış ve saydam köşeli kalır.

İlk yüklemede bu ayrım yoktu ve Play'e beyaz köşeli bir ikon gitti.

## Ekran görüntüleri

Ham ekranlar uygulamanın **kendi kodundan** üretilir:

```bash
cd mobile
TEKNIKCEP_STORE_DIR=build/store flutter test test/store
```

Sonra pazarlama çerçevelerini oluştur:

```bash
python assets/branding/generate_store_screenshots.py
```

### Neden gerçek cihaz/emülatör değil

1. **Mağaza sayfası herkese açık.** Gerçek bir hesapla çekilen görüntüler
   o hesabın müşteri adlarını, telefonlarını ve IBAN'ını Play'de
   yayınlar.
2. **Yeniden üretilebilir.** Arayüz değiştiğinde görüntüler tek komutla
   tazelenir; kimse emülatör kurup elle gezinmez.
3. **Piksel boyutu kesin.** Play en/boy oranını reddedebiliyor; burada
   çözünürlük koddan gelir, cihazın çözünürlüğünden değil.

Görüntüler tasarım değiştikçe **bayatlar**. 0.8.0'daki ekran yeniden
düzeninden sonra tazelenmeleri gerekiyor (bkz. ROADMAP § Tasarım).

## Play'e yükleme

Kimlik bilgisi yalnızca GitHub secret'ı olarak var (yerelde ve sunucuda
kopyası yok), bu yüzden yükleme yayın hattından yapılır:

```bash
gh workflow run store-listing.yml -f komut=liste   # mağazada ne var
gh workflow run store-listing.yml -f komut=yukle   # hepsini yükle
```

`yukle` önce boyutları doğrular, sonra her dil için eski görselleri
temizleyip yenilerini yükler, işler ve **işlemeden sonra tekrar okuyup
doğrular** — "commit 200 döndü" ile "mağazada yeni görsel duruyor" aynı
şey değil.

Sürüm hattına bilinçli olarak bağlanmadı: mağaza görselleri her sürümde
değişmiyor ve her yayında listeye dokunmak gereksiz inceleme kuyruğu
riski.

## Rasterleştirme notu

Windows'ta cairo kurulamıyor. SVG önce PDF'e (svglib/reportlab), sonra
PNG'ye (pypdfium2) çevriliyor. `pypdfium2`'nin varsayılan zemini
**beyaz** — `fill_color` saydam verilmezse yuvarlatılmış köşenin dışı
beyaz kalıyor.
