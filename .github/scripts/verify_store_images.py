"""Play magaza gorsellerini YUKLEMEDEN ONCE dogrular.

Play'in kurallari kati ve reddettiginde donen mesaj sebebe isaret
etmiyor ("invalid image"). Burada kirilmasi, API yanitini cozmeye
calismaktan cok daha hizli.

Kullanim:
    python verify_store_images.py icon=yol.png phoneScreenshots=dizin/
"""

import os
import struct
import sys

# https://support.google.com/googleplay/android-developer/answer/9866151
KURALLAR = {
    # (en, boy) TAM eslesmeli
    "icon": {"tam": (512, 512), "azami_mb": 1},
    "featureGraphic": {"tam": (1024, 500), "azami_mb": 15},
    # Ekran goruntuleri: her kenar 320-3840 arasi ve en/boy orani
    # 16:9 ile 9:16 arasinda. Modern telefonlarin 20:9 orani REDDEDILIYOR
    # — cihazdan ham cekilen goruntuler tam bu yuzden kabul edilmiyor.
    "phoneScreenshots": {
        "aralik": (320, 3840),
        "oran": (9 / 16, 16 / 9),
        "azami_mb": 8,
        "en_az": 2,
        "en_cok": 8,
    },
}


def png_boyutu(yol: str) -> tuple:
    with open(yol, "rb") as f:
        ham = f.read(24)
    if ham[:8] != b"\x89PNG\r\n\x1a\n":
        sys.exit(f"{yol}: PNG degil.")
    return struct.unpack(">II", ham[16:24])


def dosyalar(yol: str) -> list:
    if os.path.isdir(yol):
        return [
            os.path.join(yol, ad)
            for ad in sorted(os.listdir(yol))
            if ad.lower().endswith(".png")
        ]
    return [yol]


def dogrula(tip: str, yol: str) -> None:
    kural = KURALLAR.get(tip)
    if kural is None:
        print(f"{tip}: kural tanimli degil, atlaniyor.")
        return

    liste = dosyalar(yol)
    if not liste:
        sys.exit(f"{yol}: gorsel bulunamadi.")

    en_az = kural.get("en_az")
    if en_az and len(liste) < en_az:
        sys.exit(f"{tip}: en az {en_az} gorsel gerekli, {len(liste)} var.")
    en_cok = kural.get("en_cok")
    if en_cok and len(liste) > en_cok:
        sys.exit(f"{tip}: en cok {en_cok} gorsel olabilir, {len(liste)} var.")

    for dosya in liste:
        en, boy = png_boyutu(dosya)
        mb = os.path.getsize(dosya) / (1024 * 1024)
        ad = os.path.basename(dosya)

        if mb > kural["azami_mb"]:
            sys.exit(f"{ad}: {mb:.1f} MB — sinir {kural['azami_mb']} MB.")

        if "tam" in kural and (en, boy) != kural["tam"]:
            beklenen = "x".join(str(v) for v in kural["tam"])
            sys.exit(f"{ad}: {en}x{boy} — {tip} tam {beklenen} olmali.")

        if "aralik" in kural:
            alt, ust = kural["aralik"]
            if not (alt <= en <= ust and alt <= boy <= ust):
                sys.exit(f"{ad}: {en}x{boy} — her kenar {alt}-{ust} arasi olmali.")
            oran = en / boy
            o_alt, o_ust = kural["oran"]
            if not (o_alt - 1e-6 <= oran <= o_ust + 1e-6):
                sys.exit(
                    f"{ad}: {en}x{boy} (oran {oran:.3f}) — "
                    f"Play 16:9 ile 9:16 arasi istiyor."
                )

        print(f"  {ad}: {en}x{boy}, {mb:.2f} MB — uygun")


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    for istek in sys.argv[1:]:
        if "=" not in istek:
            sys.exit(f"Beklenen bicim tip=yol, gelen: {istek}")
        tip, yol = istek.split("=", 1)
        print(f"{tip}:")
        dogrula(tip, yol)


if __name__ == "__main__":
    main()
