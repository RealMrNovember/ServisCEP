"""Play kanallarini, yayindaki surumleri ve test kullanici gruplarini doker.

NEDEN VAR: "arkadaslarim indiremiyor" ve "Console 1 kullanici gosteriyor"
sorularinin cevabi Console'un ekraninda degil, kanal yapilandirmasinda.
Hangi kanalda hangi surum yayinda, kanal kime acik ve test grubu dogru
bagli mi — bunlar API'den kesin okunabiliyor, ekran goruntusunden
tahmin edilmesi gerekmiyor.

Kullanim:
    python play_track_info.py
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

# Play'in standart kanallari. Ozel kapali kanallar da olabilir; hepsi
# `tracks` listesinden okunuyor, burasi yalnizca sira icin.
BILINEN = ["internal", "alpha", "beta", "production"]


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


def main() -> None:
    s = oturum()
    duzenleme = kontrol(s.post(f"{TABAN}/edits"), "Duzenleme acma")["id"]

    kanallar = kontrol(
        s.get(f"{TABAN}/edits/{duzenleme}/tracks"), "Kanal listesi"
    ).get("tracks", [])

    adlar = sorted(
        {k.get("track") for k in kanallar if k.get("track")},
        key=lambda a: (BILINEN.index(a) if a in BILINEN else 99, a),
    )
    print(f"KANALLAR: {', '.join(adlar) or '(yok)'}")

    for kanal in kanallar:
        ad = kanal.get("track")
        print(f"\n=== {ad}")

        surumler = kanal.get("releases", [])
        if not surumler:
            print("  (bu kanalda surum yok)")
        for r in surumler:
            kodlar = ", ".join(str(v) for v in r.get("versionCodes", []))
            print(
                f"  surum: {r.get('name')} | kodlar: {kodlar or '-'} "
                f"| durum: {r.get('status')} "
                f"| kullanici orani: {r.get('userFraction', 1.0)}"
            )
            hedef = r.get("countryTargeting")
            if hedef:
                ulkeler = hedef.get("countries", [])
                print(
                    f"    ULKE HEDEFLEME VAR: {len(ulkeler)} ulke "
                    f"({', '.join(ulkeler[:10])}"
                    f"{'…' if len(ulkeler) > 10 else ''})"
                )

        # Test kullanicilari yalnizca kapali/ic kanallarda anlamli.
        if ad in ("production",):
            continue

        yanit = s.get(f"{TABAN}/edits/{duzenleme}/testers/{ad}")
        if yanit.status_code == 404:
            print("  test kullanicisi yapilandirmasi YOK (404)")
            continue
        if not yanit.ok:
            print(f"  test kullanicisi okunamadi ({yanit.status_code})")
            continue

        testciler = yanit.json() if yanit.text else {}
        gruplar = testciler.get("googleGroups") or []
        if gruplar:
            print(f"  test grubu: {', '.join(gruplar)}")
        else:
            print("  test grubu TANIMLI DEGIL (liste bos)")

    s.delete(f"{TABAN}/edits/{duzenleme}")


if __name__ == "__main__":
    main()
