"""Play magaza listesindeki uygulama simgesini gunceller.

NEDEN AYRI BIR IS: Play'de iki ayri simge var ve ikisi birlikte
degismiyor. Biri APK/AAB'nin icindeki launcher ikonu (telefonun ana
ekraninda gorunen), digeri magaza listesinin 512x512 simgesi (Play'de
arama sonucunda ve uygulama sayfasinda gorunen). Yeni marka isareti
0.7.7 ile uygulamaya girdi ama magaza listesi eski simgeyle kaldi:
kullanici Play'de eski logoyu, telefonunda yeni logoyu goruyordu.

Kimlik bilgisi yalnizca GitHub secret'i olarak var (yerelde ve sunucuda
kopyasi yok), bu yuzden yukleme yayin hattindan yapiliyor.

Simge HER DILDE ayri tutuluyor. Listedeki tum diller donuluyor — tek
dile yuklemek, digerlerini eski simgeyle birakirdi.
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
        # Govdeyi bastir: Play'in hata mesajlari ("edit expired", "app
        # not found") tek basina durum kodundan cok daha bilgilendirici.
        sys.exit(f"{ne} basarisiz ({yanit.status_code}): {yanit.text}")
    return yanit.json() if yanit.text else {}


def main() -> None:
    gorsel = sys.argv[1] if len(sys.argv) > 1 else "assets/branding/icon-512.png"
    veri = open(gorsel, "rb").read()
    print(f"Kaynak: {gorsel} ({len(veri)} bayt)")

    s = oturum()

    duzenleme = kontrol(s.post(f"{TABAN}/edits"), "Duzenleme acma")["id"]
    print(f"Duzenleme: {duzenleme}")

    listeler = kontrol(s.get(f"{TABAN}/edits/{duzenleme}/listings"), "Liste okuma")
    diller = [l["language"] for l in listeler.get("listings", [])]
    if not diller:
        sys.exit("Magaza listesi bulunamadi — yuklenecek dil yok.")
    print(f"Diller: {', '.join(diller)}")

    for dil in diller:
        yol = f"/edits/{duzenleme}/listings/{dil}/icon"

        # Once mevcut simgeyi sil. Play bu uctan yalnizca TEK bir simge
        # tutuyor; silmeden yuklemek "too many images" ile reddediliyor.
        kontrol(s.delete(f"{TABAN}{yol}"), f"{dil} eski simgeyi silme")

        kontrol(
            s.post(
                f"{YUKLEME}{yol}?uploadType=media",
                data=veri,
                headers={"Content-Type": "image/png"},
            ),
            f"{dil} simge yukleme",
        )
        print(f"  {dil}: yuklendi")

    kontrol(s.post(f"{TABAN}/edits/{duzenleme}:commit"), "Duzenlemeyi isleme")
    print("Isleme tamam.")

    # Isledikten SONRA dogrula. "commit 200 dondu" ile "magazada yeni
    # simge duruyor" ayni sey degil; Play sessizce eski gorseli
    # tutabilirdi.
    dogrulama = kontrol(s.post(f"{TABAN}/edits"), "Dogrulama duzenlemesi")["id"]
    for dil in diller:
        sonuc = kontrol(
            s.get(f"{TABAN}/edits/{dogrulama}/listings/{dil}/icon"),
            f"{dil} dogrulama",
        )
        gorseller = sonuc.get("images", [])
        if not gorseller:
            sys.exit(f"{dil}: islemeden sonra simge bulunamadi.")
        print(f"  {dil}: {gorseller[0].get('url', '(url yok)')}")

    s.delete(f"{TABAN}/edits/{dogrulama}")


if __name__ == "__main__":
    main()
