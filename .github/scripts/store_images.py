"""Play magaza listesindeki gorselleri okur ve gunceller.

NEDEN YAYIN HATTINDAN: Play kimlik bilgisi yalnizca GitHub secret'i
olarak var; yerelde ve sunucuda kopyasi yok.

NEDEN AYRI BIR IS: Play'de uygulamanin ICINDEKI launcher ikonu ile
magaza listesinin simgesi iki ayri varliktir ve birlikte degismezler.
Yeni marka isareti 0.7.7 ile uygulamaya girdi, magaza listesi eskisiyle
kaldi; kullanici Play'de eski, telefonunda yeni logoyu goruyordu.

Kullanim:
    python store_images.py liste
    python store_images.py yukle icon=assets/branding/play-store-icon.png
    python store_images.py yukle phoneScreenshots=dizin/
"""

import json
import os
import sys

import google.auth.transport.requests
import requests
from google.oauth2 import service_account

PAKET = "com.cicibyte.serviscep"
KAPSAM = "https://www.googleapis.com/auth/androidpublisher"
TABAN = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PAKET}"
YUKLEME = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PAKET}"

TIPLER = [
    "icon",
    "featureGraphic",
    "phoneScreenshots",
    "sevenInchScreenshots",
    "tenInchScreenshots",
    "tvBanner",
    "tvScreenshots",
    "wearScreenshots",
]

# Tek gorsel tutan tipler. Otekiler bir GALERI: yukleme ekler, degistirmez,
# bu yuzden once temizlenmeleri gerekiyor.
TEKIL = {"icon", "featureGraphic", "tvBanner"}


def oturum() -> requests.Session:
    ham = os.environ.get("PLAY_SERVICE_ACCOUNT_JSON", "")
    if not ham.strip():
        sys.exit("PLAY_SERVICE_ACCOUNT_JSON tanimli degil.")

    kimlik = service_account.Credentials.from_service_account_info(
        json.loads(ham), scopes=[KAPSAM]
    )
    kimlik.refresh(google.auth.transport.requests.Request())

    s = requests.Session()
    s.headers["Authorization"] = f"Bearer {kimlik.token}"
    return s


def kontrol(yanit: requests.Response, ne: str) -> dict:
    if not yanit.ok:
        # Govdeyi bastir: Play'in mesajlari ("edit expired", "image
        # dimensions") durum kodundan cok daha bilgilendirici.
        sys.exit(f"{ne} basarisiz ({yanit.status_code}): {yanit.text}")
    return yanit.json() if yanit.text else {}


def dilleri_al(s: requests.Session, duzenleme: str) -> list:
    listeler = kontrol(s.get(f"{TABAN}/edits/{duzenleme}/listings"), "Liste okuma")
    diller = [l["language"] for l in listeler.get("listings", [])]
    if not diller:
        sys.exit("Magaza listesi bulunamadi.")
    return diller


def komut_liste() -> None:
    s = oturum()
    duzenleme = kontrol(s.post(f"{TABAN}/edits"), "Duzenleme acma")["id"]
    try:
        for dil in dilleri_al(s, duzenleme):
            print(f"\n[{dil}]")
            for tip in TIPLER:
                sonuc = kontrol(
                    s.get(f"{TABAN}/edits/{duzenleme}/listings/{dil}/{tip}"),
                    f"{dil}/{tip} okuma",
                )
                gorseller = sonuc.get("images", [])
                print(f"  {tip}: {len(gorseller)}")
                for g in gorseller:
                    print(f"      {g.get('url', '(url yok)')}")
    finally:
        s.delete(f"{TABAN}/edits/{duzenleme}")


def dosyalari_topla(yol: str) -> list:
    if os.path.isdir(yol):
        return [
            os.path.join(yol, ad)
            for ad in sorted(os.listdir(yol))
            if ad.lower().endswith((".png", ".jpg", ".jpeg"))
        ]
    return [yol]


def komut_yukle(istekler: list) -> None:
    hazir = {}
    for istek in istekler:
        if "=" not in istek:
            sys.exit(f"Beklenen bicim tip=yol, gelen: {istek}")
        tip, yol = istek.split("=", 1)
        if tip not in TIPLER:
            sys.exit(f"Bilinmeyen gorsel tipi: {tip}")
        dosyalar = dosyalari_topla(yol)
        if not dosyalar:
            sys.exit(f"{yol} icinde gorsel yok.")
        if tip in TEKIL and len(dosyalar) > 1:
            sys.exit(f"{tip} tek gorsel tutuyor, {len(dosyalar)} dosya verildi.")
        hazir[tip] = [(d, open(d, "rb").read()) for d in dosyalar]
        print(f"{tip}: {len(dosyalar)} dosya")

    s = oturum()
    duzenleme = kontrol(s.post(f"{TABAN}/edits"), "Duzenleme acma")["id"]
    diller = dilleri_al(s, duzenleme)
    print(f"Duzenleme: {duzenleme} | Diller: {', '.join(diller)}")

    for dil in diller:
        for tip, dosyalar in hazir.items():
            yol = f"/edits/{duzenleme}/listings/{dil}/{tip}"

            # Galeri tipleri yuklemede EKLIYOR. Temizlemeden yuklemek eski
            # ekran goruntulerini yenilerinin yaninda birakirdi.
            kontrol(s.delete(f"{TABAN}{yol}"), f"{dil}/{tip} temizleme")

            for ad, veri in dosyalar:
                tur = "image/jpeg" if ad.lower().endswith((".jpg", ".jpeg")) else "image/png"
                kontrol(
                    s.post(
                        f"{YUKLEME}{yol}?uploadType=media",
                        data=veri,
                        headers={"Content-Type": tur},
                    ),
                    f"{dil}/{tip} yukleme ({os.path.basename(ad)})",
                )
            print(f"  {dil}/{tip}: {len(dosyalar)} yuklendi")

    kontrol(s.post(f"{TABAN}/edits/{duzenleme}:commit"), "Duzenlemeyi isleme")
    print("Isleme tamam.")

    # Isledikten SONRA dogrula: "commit 200 dondu" ile "magazada yeni
    # gorsel duruyor" ayni sey degil.
    dogrulama = kontrol(s.post(f"{TABAN}/edits"), "Dogrulama duzenlemesi")["id"]
    try:
        for dil in diller:
            for tip, dosyalar in hazir.items():
                sonuc = kontrol(
                    s.get(f"{TABAN}/edits/{dogrulama}/listings/{dil}/{tip}"),
                    f"{dil}/{tip} dogrulama",
                )
                bulunan = len(sonuc.get("images", []))
                if bulunan != len(dosyalar):
                    sys.exit(
                        f"{dil}/{tip}: {len(dosyalar)} beklenirken {bulunan} bulundu."
                    )
                print(f"  {dil}/{tip}: {bulunan} dogrulandi")
    finally:
        s.delete(f"{TABAN}/edits/{dogrulama}")


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] not in ("liste", "yukle"):
        sys.exit(__doc__)
    if sys.argv[1] == "liste":
        komut_liste()
    else:
        komut_yukle(sys.argv[2:])


if __name__ == "__main__":
    main()
