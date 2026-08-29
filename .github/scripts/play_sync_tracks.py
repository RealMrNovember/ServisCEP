"""Kapali testteki (alpha) surumu ic teste (internal) tasir.

NEDEN VAR: Play, bir kullaniciyi uygun oldugu EN ONCELIKLI kanaldan
besliyor ve ic test kapali testin onunde. Yalnizca alpha'ya yayin
yapilirken ic test listesindeki hesaplar aylar oncesinin surumunde
kaliyordu — uygulamayi "kullaniyoruz" diyorlardi ama ellerindeki
neredeyse baska bir uygulamaydi.

Yayin hatti artik ayni AAB'yi tek yuklemede iki kanala birden atiyor
(release.yml). Bu script GECMISI duzeltmek icin: zaten yayinda olan bir
surumu, yeni bir derleme yapmadan ic teste de tasiyor.

Yeni AAB YUKLEMEZ; yalnizca var olan surum kodunu kanala atar.

Kullanim:
    python play_sync_tracks.py
"""

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

KAYNAK = "alpha"
HEDEF = "internal"


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


def en_yuksek_kod(kanal: dict) -> int:
    kodlar = [
        int(v)
        for r in kanal.get("releases", [])
        for v in r.get("versionCodes", [])
    ]
    return max(kodlar) if kodlar else 0


def main() -> None:
    s = oturum()
    duzenleme = kontrol(s.post(f"{TABAN}/edits"), "Duzenleme acma")["id"]

    kaynak = kontrol(
        s.get(f"{TABAN}/edits/{duzenleme}/tracks/{KAYNAK}"),
        f"{KAYNAK} okuma",
    )
    hedef = kontrol(
        s.get(f"{TABAN}/edits/{duzenleme}/tracks/{HEDEF}"), f"{HEDEF} okuma"
    )

    kaynak_kod = en_yuksek_kod(kaynak)
    hedef_kod = en_yuksek_kod(hedef)

    if kaynak_kod == 0:
        sys.exit(f"{KAYNAK} kanalinda surum yok.")

    print(f"{KAYNAK}: build {kaynak_kod} | {HEDEF}: build {hedef_kod or '-'}")

    # Geriye tasima YOK: ic testte daha yeni bir sey varsa (elle
    # yuklenmis olabilir) uzerine yazmak surum dusurmek olurdu.
    if hedef_kod >= kaynak_kod:
        print(f"{HEDEF} zaten {hedef_kod} — yapilacak bir sey yok.")
        s.delete(f"{TABAN}/edits/{duzenleme}")
        return

    # Sürüm notu kaynaktan taşınıyor: iç testteki kullanıcı da neyin
    # değiştiğini görmeli.
    notlar = None
    for r in kaynak.get("releases", []):
        if kaynak_kod in [int(v) for v in r.get("versionCodes", [])]:
            notlar = r.get("releaseNotes")
            ad = r.get("name")
            break

    govde = {
        "track": HEDEF,
        "releases": [
            {
                "name": ad,
                "versionCodes": [str(kaynak_kod)],
                "status": "completed",
                **({"releaseNotes": notlar} if notlar else {}),
            }
        ],
    }

    kontrol(
        s.put(f"{TABAN}/edits/{duzenleme}/tracks/{HEDEF}", json=govde),
        f"{HEDEF} yazma",
    )
    kontrol(s.post(f"{TABAN}/edits/{duzenleme}:commit"), "Commit")
    print(f"{HEDEF} kanalina build {kaynak_kod} atandi.")

    # Geri oku: commit'in basarili donmesi, kanalin gercekten guncellendigi
    # anlamina gelmiyor.
    dogrulama = kontrol(s.post(f"{TABAN}/edits"), "Dogrulama duzenlemesi")["id"]
    sonrasi = kontrol(
        s.get(f"{TABAN}/edits/{dogrulama}/tracks/{HEDEF}"), "Dogrulama okuma"
    )
    s.delete(f"{TABAN}/edits/{dogrulama}")

    yeni_kod = en_yuksek_kod(sonrasi)
    if yeni_kod != kaynak_kod:
        sys.exit(f"Dogrulama tutmadi: {HEDEF} hala {yeni_kod}.")
    print(f"Dogrulandi: {HEDEF} = build {yeni_kod}.")


if __name__ == "__main__":
    main()
