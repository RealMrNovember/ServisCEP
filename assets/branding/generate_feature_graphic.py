"""Play magaza afisini (1024x500 "feature graphic") uretir.

Eski surum logoyu Pillow ile CIZIYORDU ve uzerinde "ServisCEP" yaziyordu.
Marka SVG'ye tasindiginda o kod olu bir ikinci tanim haline geldi:
calistirilsa hem eski logoyu hem eski adi geri getirirdi.

Artik isaret marka SVG'sinden, renkler ve yazi tipleri uygulamanin kendi
tasarim sisteminden geliyor (mobile/lib/app/palette.dart ve
mobile/assets/fonts). Magaza afisi uygulamanin ilk izlenimi — ayri bir
gorsel dilde olmasi icin sebep yok.

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
FONTLAR = os.path.join(KOK, "mobile", "assets", "fonts")
CIKTI = os.path.join(KOK, "assets", "branding", "play-feature-graphic.png")

# palette.dart § dark
ZEMIN = (0x0B, 0x0C, 0x0F)
METIN = (0xF4, 0xF6, 0xF9)
SOLUK = (0x98, 0xA2, 0xB0)
AKSAN = (0x3B, 0x82, 0xF6)

EN, BOY = 1024, 500

# Metin ve isaret, olceklenmis tuvale cizilip sona kuculuyor — Pillow'un
# kenar yumusatmasi bu boyutta yetersiz kaliyor.
KAT = 3


def main() -> None:
    w, h = EN * KAT, BOY * KAT
    tuval = Image.new("RGBA", (w, h), ZEMIN + (255,))

    # İşaretin arkasında yumuşak bir aksan halesi: düz koyu zeminde
    # 1024x500'lük bir afiş cansız duruyor.
    hale = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hale)
    hcx, hcy, hr = int(w * 0.755), h // 2, int(w * 0.16)
    hd.ellipse([hcx - hr, hcy - hr, hcx + hr, hcy + hr], fill=AKSAN + (64,))
    tuval = Image.alpha_composite(tuval, hale.filter(ImageFilter.GaussianBlur(w * 0.025)))

    isaret_boyut = int(260 * KAT)
    isaret = rasterlestir(open(ISARET, encoding="utf-8").read(), isaret_boyut)
    tuval.paste(isaret, (hcx - isaret_boyut // 2, hcy - isaret_boyut // 2), isaret)

    d = ImageDraw.Draw(tuval)
    baslik = ImageFont.truetype(os.path.join(FONTLAR, "Archivo-Bold.ttf"), 88 * KAT)
    slogan = ImageFont.truetype(os.path.join(FONTLAR, "Barlow-Medium.ttf"), 34 * KAT)

    sol = 72 * KAT

    # Dikey yerleşim ÖLÇÜLEREK yapılıyor, sabit sayılarla değil: yazı tipi
    # ya da punto değiştiğinde sabitler sessizce üst üste biner. İlk
    # denemede aksan çizgisi tam da böyle başlığın üstüne düşmüştü.
    baslik_metni = "TeknikCEP"
    slogan_metni = "Saha servis yönetimi cebinizde"

    bk = d.textbbox((0, 0), baslik_metni, font=baslik)
    sk = d.textbbox((0, 0), slogan_metni, font=slogan)
    baslik_y = bk[3] - bk[1]
    slogan_y = sk[3] - sk[1]

    cizgi_bosluk = 26 * KAT
    cizgi_kalinlik = 5 * KAT
    slogan_bosluk = 22 * KAT

    toplam = baslik_y + cizgi_bosluk + cizgi_kalinlik + slogan_bosluk + slogan_y
    ust = (h - toplam) // 2

    d.text((sol, ust - bk[1]), baslik_metni, font=baslik, fill=METIN)

    cizgi_ust = ust + baslik_y + cizgi_bosluk
    d.rounded_rectangle(
        [sol, cizgi_ust, sol + 104 * KAT, cizgi_ust + cizgi_kalinlik],
        radius=cizgi_kalinlik // 2,
        fill=AKSAN,
    )

    slogan_ust = cizgi_ust + cizgi_kalinlik + slogan_bosluk
    d.text((sol, slogan_ust - sk[1]), slogan_metni, font=slogan, fill=SOLUK)

    # Play afişi saydamlık kabul etmiyor; RGB'ye düşürülüyor.
    tuval.resize((EN, BOY), Image.LANCZOS).convert("RGB").save(CIKTI)
    print(f"Tamamlandi: {CIKTI} ({EN}x{BOY})")


if __name__ == "__main__":
    main()
