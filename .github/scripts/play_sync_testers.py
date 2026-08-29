"""Kapali testteki (alpha) test kullanici grubunu ic teste (internal) tasir.

NEDEN VAR: iki kanal ayni derlemeyi tasiyor ama test kullanicilari ayri
yonetiliyordu; kapali teste katilan biri ic testte yoktu. Surec iki
kanalda birlikte yurusun isteniyor.

NEDEN GUVENLI: bu script CALISTIRILMADAN ONCE iki kanalin ayni surumu
tasidigindan emin ol (play_sync_tracks.py). Play, kullaniciyi uygun
oldugu EN ONCELIKLI kanaldan besliyor ve ic test kapali testin onunde;
kanallar ayriyken grubu ic teste eklemek, herkesi ic testteki (muhtemelen
daha eski) surume dusururdu.

BILINEN KISIT (denendi 2026-08-29): ic test kanali Console'da yeni
test kullanicisi modeline gecirilmisse Play bu yazmayi 403 ile
reddediyor:

    "The internal track has been upgraded to use open or closed
     testing; switch back to communities-based testing before using
     the API for this track."

Bu durumda ic test kullanicilari yalnizca Console'dan, e-posta
listesiyle yonetilebiliyor — API'den grup atanamiyor. Script bunu
sessizce gecmiyor, Play'in mesajiyla birlikte kiriliyor.

Ic test kanalinin 100 test kullanicisi siniri da var.

Kullanim:
    python play_sync_testers.py
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

    # Once surum esitligi: ayrik kanallara grup eklemek kullaniciyi eski
    # surume dusururdu.
    kaynak_kanal = kontrol(
        s.get(f"{TABAN}/edits/{duzenleme}/tracks/{KAYNAK}"), "kaynak kanal"
    )
    hedef_kanal = kontrol(
        s.get(f"{TABAN}/edits/{duzenleme}/tracks/{HEDEF}"), "hedef kanal"
    )
    kaynak_kod = en_yuksek_kod(kaynak_kanal)
    hedef_kod = en_yuksek_kod(hedef_kanal)

    if hedef_kod < kaynak_kod:
        s.delete(f"{TABAN}/edits/{duzenleme}")
        sys.exit(
            f"DURDURULDU: {HEDEF} build {hedef_kod}, {KAYNAK} build "
            f"{kaynak_kod}. Once kanallari esitle (play_sync_tracks.py); "
            f"aksi halde grup ic teste eklenince herkes eski surume duser."
        )

    gruplar = (
        kontrol(
            s.get(f"{TABAN}/edits/{duzenleme}/testers/{KAYNAK}"),
            f"{KAYNAK} test kullanicilari",
        ).get("googleGroups")
        or []
    )

    if not gruplar:
        s.delete(f"{TABAN}/edits/{duzenleme}")
        sys.exit(f"{KAYNAK} kanalinda tanimli grup yok.")

    print(f"{KAYNAK} grubu: {', '.join(gruplar)}")

    yanit = s.put(
        f"{TABAN}/edits/{duzenleme}/testers/{HEDEF}",
        json={"googleGroups": gruplar},
    )
    if not yanit.ok:
        s.delete(f"{TABAN}/edits/{duzenleme}")
        sys.exit(
            f"{HEDEF} kanalina grup YAZILAMADI ({yanit.status_code}): "
            f"{yanit.text}"
        )

    kontrol(s.post(f"{TABAN}/edits/{duzenleme}:commit"), "Commit")
    print(f"{HEDEF} kanalina yazildi.")

    # Geri oku. Play bazi alanlari sessizce yok sayabiliyor; "commit
    # basarili" yaniti degerin kaydedildiginin kaniti degil.
    dogrulama = kontrol(s.post(f"{TABAN}/edits"), "Dogrulama duzenlemesi")["id"]
    sonrasi = (
        kontrol(
            s.get(f"{TABAN}/edits/{dogrulama}/testers/{HEDEF}"),
            "Dogrulama okuma",
        ).get("googleGroups")
        or []
    )
    s.delete(f"{TABAN}/edits/{dogrulama}")

    if sorted(sonrasi) != sorted(gruplar):
        sys.exit(
            f"Dogrulama TUTMADI: {HEDEF} kanalinda okunan {sonrasi}, "
            f"beklenen {gruplar}. Play bu kanalda grup desteklemiyor "
            f"olabilir; Console'dan e-posta listesiyle yonetilmesi gerekir."
        )

    print(f"Dogrulandi: {HEDEF} grubu = {', '.join(sonrasi)}")


if __name__ == "__main__":
    main()
