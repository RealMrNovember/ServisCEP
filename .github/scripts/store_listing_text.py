"""Play magaza listesindeki METINLERI okur ve gunceller.

NEDEN VAR: liste metni Play Console'a ELLE girilmisti ve cift kodlanmis
olarak kaydedilmisti — magazada "isletmeleri" yerine "iAYletmeleri",
"icin" yerine "iA§in", "uygulamasi" yerine "uygulamasA+-" goruunuyordu.
UTF-8 baytlarinin Latin-1 diye okunmasinin klasik izi. Metin artik
depoda tutuluyor ve buradan yukleniyor: elle girilen metin bir daha
sessizce bozulamaz ve degisiklik diff'te gorunur.

Kaynak dosyalar (acikca UTF-8 okunur):
    assets/branding/store-listing/<dil>.short.txt
    assets/branding/store-listing/<dil>.full.txt

Kullanim:
    python store_listing_text.py liste
    python store_listing_text.py yukle
"""

import io
import json
import os
import sys

import google.auth.transport.requests
import requests
from google.oauth2 import service_account

PAKET = "com.cicibyte.serviscep"
KAPSAM = "https://www.googleapis.com/auth/androidpublisher"
TABAN = (
    "https://androidpublisher.googleapis.com/androidpublisher/v3"
    f"/applications/{PAKET}"
)

KAYNAK_DIZIN = "assets/branding/store-listing"

# Play'in kendi sinirlari. Asilirsa API bunu "invalid argument" diye
# donuyor ve hangi alanin sorunlu oldugunu soylemiyor.
SINIR_KISA = 80
SINIR_TAM = 4000


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
        sys.exit(f"{ne} basarisiz ({yanit.status_code}): {yanit.text}")
    return yanit.json() if yanit.text else {}


def metinleri_oku(dil: str) -> tuple:
    """Depodaki metinleri ACIKCA utf-8 olarak okur.

    Kodlama parametresi bilincli: varsayilan kodlama isletim sistemine
    gore degisiyor ve Windows'ta cp1254 oluyor. Bu dosyanin tum varlik
    sebebi bir kodlama hatasi; ayni hataya burada dusmek olurdu.
    """
    kisa_yol = os.path.join(KAYNAK_DIZIN, f"{dil}.short.txt")
    tam_yol = os.path.join(KAYNAK_DIZIN, f"{dil}.full.txt")

    kisa = io.open(kisa_yol, encoding="utf-8").read().strip()
    tam = io.open(tam_yol, encoding="utf-8").read().strip()

    if len(kisa) > SINIR_KISA:
        sys.exit(f"{kisa_yol}: {len(kisa)} karakter, sinir {SINIR_KISA}.")
    if len(tam) > SINIR_TAM:
        sys.exit(f"{tam_yol}: {len(tam)} karakter, sinir {SINIR_TAM}.")

    return kisa, tam


def bozuk_mu(metin: str) -> bool:
    """Cift kodlama izi tasiyor mu.

    "Ã", "Å", "Ä" harfleri Turkce metinde gecmez; UTF-8 baytlarinin
    Latin-1 diye okunmasinin imzasidir.
    """
    return any(im in metin for im in ("Ã", "Å", "Ä", "Å¸", "Â"))


def listele(s: requests.Session) -> None:
    duzenleme = kontrol(s.post(f"{TABAN}/edits"), "Duzenleme acma")["id"]
    listeler = kontrol(
        s.get(f"{TABAN}/edits/{duzenleme}/listings"), "Liste okuma"
    )

    for l in listeler.get("listings", []):
        dil = l.get("language")
        kisa = l.get("shortDescription", "")
        tam = l.get("fullDescription", "")
        print(f"--- {dil} | baslik: {l.get('title', '')}")
        print(f"    kisa ({len(kisa)}): {kisa[:120]}")
        print(f"    tam  ({len(tam)}): {tam[:120]}")
        if bozuk_mu(kisa) or bozuk_mu(tam):
            print("    !!! CIFT KODLAMA IZI VAR")

    s.delete(f"{TABAN}/edits/{duzenleme}")


def yukle(s: requests.Session) -> None:
    diller = sorted(
        {
            ad.rsplit(".", 2)[0]
            for ad in os.listdir(KAYNAK_DIZIN)
            if ad.endswith(".txt")
        }
    )
    if not diller:
        sys.exit(f"{KAYNAK_DIZIN} altinda metin dosyasi yok.")

    duzenleme = kontrol(s.post(f"{TABAN}/edits"), "Duzenleme acma")["id"]

    for dil in diller:
        kisa, tam = metinleri_oku(dil)

        # Mevcut basligi koruyoruz: baslik marka adi ve bu script'in isi
        # degil. Yalnizca aciklamalar yaziliyor.
        mevcut = kontrol(
            s.get(f"{TABAN}/edits/{duzenleme}/listings/{dil}"),
            f"{dil} listesi okuma",
        )

        govde = {
            "language": dil,
            "title": mevcut.get("title", ""),
            "shortDescription": kisa,
            "fullDescription": tam,
            "video": mevcut.get("video", ""),
        }

        # requests, json= ile gonderirken UTF-8 kodluyor; ayrica
        # ensure_ascii kapatilmiyor cunku JSON kacislari da gecerli.
        kontrol(
            s.put(f"{TABAN}/edits/{duzenleme}/listings/{dil}", json=govde),
            f"{dil} listesi yazma",
        )
        print(f"{dil}: kisa {len(kisa)} / tam {len(tam)} karakter yazildi")

    kontrol(s.post(f"{TABAN}/edits/{duzenleme}:commit"), "Commit")
    print("Islendi.")

    # Yazdiktan sonra GERI OKU: "commit basarili" yaniti, metnin dogru
    # kodlamayla kaydedildigini kanitlamiyor. Bozuk kaydedilen metin de
    # basariyla commit ediliyordu.
    dogrulama = kontrol(s.post(f"{TABAN}/edits"), "Dogrulama duzenlemesi")["id"]
    hata = False
    for dil in diller:
        okunan = kontrol(
            s.get(f"{TABAN}/edits/{dogrulama}/listings/{dil}"),
            f"{dil} dogrulama",
        )
        beklenen_kisa, beklenen_tam = metinleri_oku(dil)
        if okunan.get("shortDescription") != beklenen_kisa:
            print(f"{dil}: KISA aciklama beklenenle ayni degil")
            hata = True
        if okunan.get("fullDescription") != beklenen_tam:
            print(f"{dil}: TAM aciklama beklenenle ayni degil")
            hata = True
        if not hata:
            print(f"{dil}: dogrulandi")
    s.delete(f"{TABAN}/edits/{dogrulama}")

    if hata:
        sys.exit("Yazilan metin geri okundugunda tutmadi.")


def main() -> None:
    komut = sys.argv[1] if len(sys.argv) > 1 else "liste"
    s = oturum()
    if komut == "liste":
        listele(s)
    elif komut == "yukle":
        yukle(s)
    else:
        sys.exit(f"Bilinmeyen komut: {komut}")


if __name__ == "__main__":
    main()
