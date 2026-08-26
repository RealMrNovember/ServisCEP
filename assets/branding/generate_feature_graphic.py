"""Play magaza afisini (1024x500 "feature graphic") uretir.

Eski surum logoyu Pillow ile CIZIYORDU ve uzerinde "ServisCEP" yaziyordu.
Marka SVG'ye tasindiginda o kod olu bir ikinci tanim haline geldi:
calistirilsa hem eski logoyu hem eski adi geri getirirdi.

Afis URUNU gosteriyor. Yalnizca logo ve slogan tasiyan bir afis,
kullaniciya uygulamanin neye benzedigi hakkinda hicbir sey soylemiyor;
magazada karar veren sey ekranin kendisi. Telefon maketindeki goruntu
mobile/build/store/01-pano.png — yani afiste gorunen ekran uygulamanin
GERCEK ekrani, cizilmis bir taklidi degil.

Renkler ve yazi tipleri uygulamanin tasarim sisteminden
(mobile/lib/app/palette.dart, mobile/assets/fonts). Magaza afisi
uygulamanin ilk izlenimi — ayri bir gorsel dilde olmasi icin sebep yok.

Onkosul: mobile/ dizininde `flutter test test/store` (ham ekranlari uretir)

Kullanim:
    python assets/branding/generate_feature_graphic.py
"""

import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# Rasterlestirme generate_assets'ten aliniyor, kopyalanmiyor. Kopya
# durdugu surece iki yerde ayri ayri bozulabiliyor: beyaz zemin hatasi
# birinde duzeltildiginde digerinde kaldi ve isaretin arkasinda beyaz
# kare olarak afise cikti.
from generate_assets import rasterlestir

KOK = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ISARET = os.path.join(KOK, "mobile", "assets", "brand", "teknikcep-b-plaka-appicon-512.svg")
EKRAN = os.path.join(KOK, "mobile", "build", "store", "01-pano.png")
FONTLAR = os.path.join(KOK, "mobile", "assets", "fonts")
CIKTI = os.path.join(KOK, "assets", "branding", "play-feature-graphic.png")

# palette.dart § dark
ZEMIN = (0x0B, 0x0C, 0x0F)
YUZEY = (0x14, 0x16, 0x1B)
KENARLIK = (0x26, 0x2A, 0x33)
METIN = (0xF4, 0xF6, 0xF9)
SOLUK = (0x98, 0xA2, 0xB0)
AKSAN = (0x3B, 0x82, 0xF6)

EN, BOY = 1024, 500

# Metin ve isaret olceklenmis tuvale cizilip sona kuculuyor — Pillow'un
# kenar yumusatmasi bu boyutta yetersiz kaliyor.
KAT = 3

# Uc kisa vaat, tam cumleden daha hizli okunuyor. Afis kucuk boyutlarda
# da gosteriliyor; uzun metin orada tamamen kayboluyor.
VAATLER = ["Çevrimdışı çalışır", "Teklif ve PDF", "Cari hesap takibi"]


def font(ad: str, punto: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(os.path.join(FONTLAR, ad), punto)


def telefon_maketi(yukseklik: int) -> Image.Image:
    """Ekran goruntusunu ince cerceveli bir telefon govdesine yerlestirir."""
    ham = Image.open(EKRAN).convert("RGB")

    cerceve = max(2, yukseklik // 90)
    ic_yukseklik = yukseklik - cerceve * 2
    olcek = ic_yukseklik / ham.height
    ic_genislik = int(ham.width * olcek)
    ekran = ham.resize((ic_genislik, ic_yukseklik), Image.LANCZOS)

    genislik = ic_genislik + cerceve * 2
    yaricap = genislik // 9

    govde = Image.new("RGBA", (genislik, yukseklik), (0, 0, 0, 0))
    d = ImageDraw.Draw(govde)
    d.rounded_rectangle(
        [0, 0, genislik - 1, yukseklik - 1], radius=yaricap, fill=YUZEY + (255,)
    )

    # Ekran ic yaricapla kirpiliyor; aksi halde koseleri govdenin disina
    # tasiyor ve cerceve kirik gorunuyor.
    maske = Image.new("L", ekran.size, 0)
    ImageDraw.Draw(maske).rounded_rectangle(
        [0, 0, ekran.width - 1, ekran.height - 1],
        radius=max(1, yaricap - cerceve),
        fill=255,
    )
    govde.paste(ekran, (cerceve, cerceve), maske)

    d.rounded_rectangle(
        [0, 0, genislik - 1, yukseklik - 1],
        radius=yaricap,
        outline=KENARLIK + (255,),
        width=cerceve,
    )
    return govde


def main() -> None:
    w, h = EN * KAT, BOY * KAT
    tuval = Image.new("RGBA", (w, h), ZEMIN + (255,))

    # Telefonun arkasinda yumusak aksan halesi: duz koyu zeminde koyu bir
    # maket zeminden ayrilmiyor.
    hale = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hcx, hcy, hr = int(w * 0.72), int(h * 0.55), int(w * 0.20)
    ImageDraw.Draw(hale).ellipse(
        [hcx - hr, hcy - hr, hcx + hr, hcy + hr], fill=AKSAN + (58,)
    )
    tuval = Image.alpha_composite(tuval, hale.filter(ImageFilter.GaussianBlur(w * 0.03)))

    # Maket ALTTAN tasiyor. Tamami sigdirilsaydi kucuk kalir ve ekrandaki
    # hicbir sey okunmazdi; tasan maket hem daha buyuk hem "devami var"
    # hissi veriyor.
    maket = telefon_maketi(int(h * 0.88))
    tuval.paste(maket, (hcx - maket.width // 2, int(h * 0.20)), maket)

    d = ImageDraw.Draw(tuval)
    baslik_font = font("Archivo-Bold.ttf", 80 * KAT)
    slogan_font = font("Barlow-Medium.ttf", 30 * KAT)
    vaat_font = font("Barlow-SemiBold.ttf", 24 * KAT)

    sol = 68 * KAT
    isaret_olcu = 60 * KAT
    isaret = rasterlestir(open(ISARET, encoding="utf-8").read(), isaret_olcu)

    baslik_metni = "TeknikCEP"
    slogan_metni = "Saha servis yönetimi cebinizde"

    bk = d.textbbox((0, 0), baslik_metni, font=baslik_font)
    sk = d.textbbox((0, 0), slogan_metni, font=slogan_font)
    vk = d.textbbox((0, 0), VAATLER[0], font=vaat_font)

    baslik_y = bk[3] - bk[1]
    slogan_y = sk[3] - sk[1]
    vaat_y = vk[3] - vk[1]

    # Dikey yerlesim OLCULEREK yapiliyor, sabit sayilarla degil: yazi tipi
    # ya da punto degistiginde sabitler sessizce ust uste biniyor. Ilk
    # denemede aksan cizgisi tam da boyle basligin ustune dusmustu.
    b1 = 24 * KAT
    b2 = 32 * KAT
    satir_araligi = 18 * KAT
    vaat_blogu = vaat_y * len(VAATLER) + satir_araligi * (len(VAATLER) - 1)

    toplam = isaret_olcu + b1 + baslik_y + b1 + slogan_y + b2 + vaat_blogu
    ust = (h - toplam) // 2

    tuval.paste(isaret, (sol, ust), isaret)
    y = ust + isaret_olcu + b1

    d.text((sol, y - bk[1]), baslik_metni, font=baslik_font, fill=METIN)
    y += baslik_y + b1

    d.text((sol, y - sk[1]), slogan_metni, font=slogan_font, fill=SOLUK)
    y += slogan_y + b2

    for metin in VAATLER:
        nokta_r = 5 * KAT
        nokta_y = y + vaat_y // 2
        d.ellipse(
            [sol, nokta_y - nokta_r, sol + nokta_r * 2, nokta_y + nokta_r], fill=AKSAN
        )
        kutu = d.textbbox((0, 0), metin, font=vaat_font)
        d.text(
            (sol + nokta_r * 2 + 16 * KAT, y - kutu[1]),
            metin,
            font=vaat_font,
            fill=METIN,
        )
        y += vaat_y + satir_araligi

    # Play afisi saydamlik kabul etmiyor; RGB'ye dusuruluyor.
    tuval.resize((EN, BOY), Image.LANCZOS).convert("RGB").save(CIKTI)
    print(f"Tamamlandi: {CIKTI} ({EN}x{BOY})")


if __name__ == "__main__":
    main()
