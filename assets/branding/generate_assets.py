"""TeknikCEP marka varliklarini uretir: PNG ikon seti + favicon.ico.

Kaynak TEK: mobile/assets/brand/teknikcep-b-plaka-appicon-512.svg
Uygulama simgesi, mağaza simgesi ve favicon aynı dosyadan turetilir;
aksi halde yuzeyler zamanla birbirinden sapar (bir kez yasandi: uygulama
icindeki simge yenilendi, magaza simgesi eskisiyle kaldi).

Windows'ta cairo kurulamiyor. Rasterlestirme dolayli yoldan yapiliyor:
SVG -> PDF (svglib/reportlab) -> PNG (pypdfium2). Bu yol bu depoda daha
once kanitlandi.

Kucuk boyutlar 512'den degil, YUKSEK cozunurlukten kuculterek uretiliyor
(LANCZOS) — 16px favicon 512'den tek adimda kuculdugunde bulaniklasiyor.

Kullanim:
    python assets/branding/generate_assets.py
"""

import io
import os

import pypdfium2 as pdfium
from PIL import Image
from reportlab.graphics import renderPDF
from svglib.svglib import svg2rlg

KOK = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KAYNAK = os.path.join(KOK, "mobile", "assets", "brand", "teknikcep-b-plaka-appicon-512.svg")
HEDEF = os.path.join(KOK, "assets", "branding")

# Ara raster. 2048, en buyuk ciktinin (512) dort kati — kucultme her
# boyutta en az bir tam piksel adimi birakiyor.
ARA = 2048

BOYUTLAR = {
    # Play magaza listesi bu dosyayi kullaniyor (tam 512x512 sart).
    "icon-512.png": 512,
    "icon-192.png": 192,
    "icon-180.png": 180,
    "icon-128.png": 128,
    "icon-64.png": 64,
    "icon-32.png": 32,
    "icon-16.png": 16,
    "apple-touch-icon.png": 180,
}

FAVICON_BOYUTLARI = [16, 32, 48]


def rasterlestir(svg_yolu: str, boyut: int) -> Image.Image:
    cizim = svg2rlg(svg_yolu)
    # svglib SVG'yi kendi birimlerinde okuyor; olcegi PDF asamasinda
    # veriyoruz ki kenar yumusatma hedef cozunurlukte yapilsin.
    olcek = boyut / cizim.width
    cizim.width *= olcek
    cizim.height *= olcek
    cizim.scale(olcek, olcek)

    pdf = io.BytesIO()
    renderPDF.drawToFile(cizim, pdf)
    pdf.seek(0)

    belge = pdfium.PdfDocument(pdf.read())
    sayfa = belge[0]
    goruntu = sayfa.render(scale=1).to_pil().convert("RGBA")
    belge.close()

    if goruntu.size != (boyut, boyut):
        goruntu = goruntu.resize((boyut, boyut), Image.LANCZOS)
    return goruntu


def main() -> None:
    ana = rasterlestir(KAYNAK, ARA)

    for ad, boyut in BOYUTLAR.items():
        ana.resize((boyut, boyut), Image.LANCZOS).save(os.path.join(HEDEF, ad))
        print(f"  {ad} ({boyut}x{boyut})")

    favicon = [ana.resize((b, b), Image.LANCZOS) for b in FAVICON_BOYUTLARI]
    favicon[0].save(
        os.path.join(HEDEF, "favicon.ico"),
        format="ICO",
        sizes=[(b, b) for b in FAVICON_BOYUTLARI],
        append_images=favicon[1:],
    )
    print(f"  favicon.ico ({', '.join(str(b) for b in FAVICON_BOYUTLARI)})")


if __name__ == "__main__":
    main()
