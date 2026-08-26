"""Ham uygulama ekranlarini Play magaza gorsellerine donusturur.

Ham ekran goruntusu magazada zayif kaliyor: kullanici listede 4-5 kucuk
kucultulmus kareyi kaydirarak geciyor ve arayuzun kendisini okuyamiyor.
Her karenin en ustunde ne ise yaradigini soyleyen tek bir cumle, o
kaydirmada okunabilen tek sey oluyor.

Girdi: mobile/build/store/*.png (flutter test test/store uretir)
Cikti: assets/branding/store/*.png (yayin hattinin yukledigi dizin)

Kullanim:
    python assets/branding/generate_store_screenshots.py
"""

import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

KOK = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KAYNAK = os.path.join(KOK, "mobile", "build", "store")
HEDEF = os.path.join(KOK, "assets", "branding", "store")
FONTLAR = os.path.join(KOK, "mobile", "assets", "fonts")

# palette.dart § dark
ZEMIN = (0x0B, 0x0C, 0x0F)
METIN = (0xF4, 0xF6, 0xF9)
SOLUK = (0x98, 0xA2, 0xB0)
AKSAN = (0x3B, 0x82, 0xF6)

EN, BOY = 1080, 1920

# Her karenin basligi. Ozellik degil FAYDA anlatiyor: "İş listesi" degil
# "Sahadaki her iş takipte" — kullanici ozellik adi aramiyor, isini
# nasil kolaylastiracagini ariyor.
BASLIKLAR = {
    "01-pano": ("Günün işleri tek ekranda", "Kim, saat kaçta, ne kadar"),
    "02-isler": ("Sahadaki her iş takipte", "Talepten tamamlamaya tek akış"),
    "03-musteriler": ("Müşteri geçmişi elinizin altında", "Kayıt, iletişim ve bakiye bir arada"),
    "04-belgeler": ("Teklifi sahada hazırla", "PDF olarak anında paylaş"),
}

SIRA = ["01-pano", "02-isler", "03-musteriler", "04-belgeler"]


def font(ad: str, punto: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(os.path.join(FONTLAR, ad), punto)


def yuvarlat(gorsel: Image.Image, yaricap: int) -> Image.Image:
    maske = Image.new("L", gorsel.size, 0)
    ImageDraw.Draw(maske).rounded_rectangle(
        [0, 0, gorsel.width - 1, gorsel.height - 1], radius=yaricap, fill=255
    )
    sonuc = gorsel.convert("RGBA")
    sonuc.putalpha(maske)
    return sonuc


def kare_uret(ad: str, baslik: str, altbaslik: str) -> Image.Image:
    ham = Image.open(os.path.join(KAYNAK, f"{ad}.png")).convert("RGB")

    tuval = Image.new("RGB", (EN, BOY), ZEMIN)

    # Ust bolgede yumusak bir aksan halesi — duz koyu zemin cansiz duruyor
    # ve baslik zeminden ayrilmiyor.
    hale = Image.new("RGBA", (EN, BOY), (0, 0, 0, 0))
    ImageDraw.Draw(hale).ellipse(
        [-EN // 3, -BOY // 5, EN + EN // 3, BOY // 3], fill=AKSAN + (46,)
    )
    tuval = Image.alpha_composite(
        tuval.convert("RGBA"), hale.filter(ImageFilter.GaussianBlur(EN * 0.08))
    ).convert("RGB")

    d = ImageDraw.Draw(tuval)
    b_font = font("Archivo-Bold.ttf", 62)
    a_font = font("Barlow-Medium.ttf", 38)

    kenar = 72
    # Baslik iki satira sigmayabilir; genislige gore sariliyor.
    satirlar = []
    kelimeler = baslik.split()
    satir = ""
    for kelime in kelimeler:
        deneme = f"{satir} {kelime}".strip()
        if d.textlength(deneme, font=b_font) <= EN - kenar * 2:
            satir = deneme
        else:
            satirlar.append(satir)
            satir = kelime
    satirlar.append(satir)

    y = 96
    for s in satirlar:
        kutu = d.textbbox((0, 0), s, font=b_font)
        d.text((kenar, y - kutu[1]), s, font=b_font, fill=METIN)
        y += (kutu[3] - kutu[1]) + 18

    y += 10
    ak = d.textbbox((0, 0), altbaslik, font=a_font)
    d.text((kenar, y - ak[1]), altbaslik, font=a_font, fill=SOLUK)
    y += (ak[3] - ak[1]) + 56

    # Ekran, kalan alana sigacak sekilde olcekleniyor ve ALTTAN tasiyor:
    # tamami sigdirilsaydi kucucuk kalirdi. Ust kismi okunakli olmasi
    # yeterli — kullanici zaten arayuzun karakterine bakiyor.
    kalan = BOY - y
    genislik = EN - kenar * 2
    olcek = genislik / ham.width
    yeni_boy = int(ham.height * olcek)
    ekran = ham.resize((genislik, yeni_boy), Image.LANCZOS)
    if yeni_boy > kalan:
        ekran = ekran.crop((0, 0, genislik, kalan))

    ekran = yuvarlat(ekran, 40)

    # Ince bir kenarlik: koyu ekran koyu zeminde eriyor.
    cerceve = Image.new("RGBA", ekran.size, (0, 0, 0, 0))
    ImageDraw.Draw(cerceve).rounded_rectangle(
        [0, 0, ekran.width - 1, ekran.height - 1],
        radius=40,
        outline=(0x26, 0x2A, 0x33, 255),
        width=3,
    )
    ekran = Image.alpha_composite(ekran, cerceve)

    tuval.paste(ekran, (kenar, y), ekran)
    return tuval


def main() -> None:
    os.makedirs(HEDEF, exist_ok=True)
    for ad in SIRA:
        baslik, altbaslik = BASLIKLAR[ad]
        kare_uret(ad, baslik, altbaslik).save(os.path.join(HEDEF, f"{ad}.png"))
        print(f"  {ad}.png ({EN}x{BOY})")


if __name__ == "__main__":
    main()
