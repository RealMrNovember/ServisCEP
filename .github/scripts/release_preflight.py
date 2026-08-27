"""Sürüm etiketini yayına çıkmadan ÖNCE denetler.

Kullanım:  python3 .github/scripts/release_preflight.py v0.8.0

Neden var: 0.7.8'i yayınlamaya çalışırken üç ayrı sebeple takıldık ve
üçü de ancak yayın anında görüldü. Buradaki kontroller o üç hatanın
birebir karşılığı — bir daha sessizce geçmesinler diye.

Betik bilerek ayrı bir dosyada: workflow içine gömülü kabuk hem YAML
girintisini bozuyor hem yerelde çalıştırılamıyor. Etiketi atmadan önce
elle de koşturulabilir:

    python3 .github/scripts/release_preflight.py v0.8.0
"""

from __future__ import annotations

import pathlib
import re
import subprocess
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
PUBSPEC = REPO_ROOT / "mobile" / "pubspec.yaml"
LOCK = REPO_ROOT / "mobile" / "pubspec.lock"

hatalar: list[str] = []


def hata(mesaj: str) -> None:
    hatalar.append(mesaj)


def pubspec_surumu() -> tuple[str, int]:
    """pubspec.yaml'daki `version: X.Y.Z+N` satırı."""
    metin = PUBSPEC.read_text(encoding="utf-8")
    eslesme = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", metin, re.M)
    if not eslesme:
        print("HATA: pubspec.yaml içinde `version: X.Y.Z+N` satırı yok.", file=sys.stderr)
        raise SystemExit(1)
    return eslesme.group(1), int(eslesme.group(2))


def onceki_etiketler() -> list[str]:
    try:
        cikti = subprocess.run(
            ["git", "tag", "--list", "v*"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return []
    return [s.strip() for s in cikti.splitlines() if s.strip()]


def etiketin_yapisi(etiket: str) -> int | None:
    """Bir etiketteki pubspec yapı numarası (versionCode)."""
    try:
        icerik = subprocess.run(
            ["git", "show", f"{etiket}:mobile/pubspec.yaml"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    eslesme = re.search(r"^version:\s*\d+\.\d+\.\d+\+(\d+)\s*$", icerik, re.M)
    return int(eslesme.group(1)) if eslesme else None


def kontrol_surum_eslesmesi(etiket: str, surum: str) -> None:
    """Etiket ile pubspec sürümü birebir aynı olmalı.

    Aksi halde Play'e etiketin söylediğinden BAŞKA bir sürüm çıkar ve
    sürüm notu yanlış kayda yazılır.
    """
    beklenen = f"v{surum}"
    if etiket != beklenen:
        hata(
            f"Etiket {etiket}, pubspec sürümü {surum} — uyuşmuyor. "
            f"Beklenen etiket: {beklenen}"
        )


def kontrol_yapi_numarasi(yapi: int, etiket: str) -> None:
    """versionCode her yayında ARTMALI.

    Play aynı versionCode'u ikinci kez kabul etmiyor. 0.7.8'de tam olarak
    bu yaşandı: dal da main de 0.7.7+31'de kalmıştı, etiket atılsa bile
    yayın reddedilecekti.
    """
    en_yuksek = 0
    kaynak = None
    for aday in onceki_etiketler():
        # Yayınlanmakta olan etiket "önceki" DEĞİLDİR. Etiket atıldıktan
        # sonra iş onun üzerinde koştuğu için kendisi de listede görünüyor
        # ve kontrol kendi kendini engelliyordu.
        if aday == etiket:
            continue
        onceki = etiketin_yapisi(aday)
        if onceki is not None and onceki > en_yuksek:
            en_yuksek, kaynak = onceki, aday

    if kaynak is None:
        return

    if yapi <= en_yuksek:
        hata(
            f"Yapı numarası {yapi}, önceki en yüksek {en_yuksek} ({kaynak}) — "
            f"artmamış. Play aynı versionCode'u ikinci kez kabul etmiyor."
        )


def kontrol_kilit_dosyasi() -> None:
    """pubspec.lock, pubspec.yaml'daki HER doğrudan bağımlılığı içermeli.

    Kilit dosyası depoda tutuluyor. Bağımlılık eklenip kilit
    güncellenmezse çözüm makineden makineye değişir; 0.7.8'de
    `workmanager` tam olarak böyle eklenmişti.

    NOT: Asıl yaptırım CI'daki `flutter pub get --enforce-lockfile`.
    Buradaki kontrol etiket atmadan önce yerelde de görünsün diye var.
    """
    if not LOCK.exists():
        hata("mobile/pubspec.lock yok.")
        return

    metin = PUBSPEC.read_text(encoding="utf-8")
    bolum = re.search(r"^dependencies:\s*$(.*?)^\S", metin, re.M | re.S)
    if not bolum:
        return

    kilit = LOCK.read_text(encoding="utf-8")
    for satir in bolum.group(1).splitlines():
        ad = re.match(r"^  ([a-z_][a-z0-9_]*):", satir)
        if not ad:
            continue
        paket = ad.group(1)
        if paket == "flutter":
            continue
        if not re.search(rf"^  {re.escape(paket)}:\s*$", kilit, re.M):
            hata(
                f"`{paket}` pubspec.yaml'da var ama pubspec.lock'ta yok — "
                f"kilit güncellenmemiş (`flutter pub get` çalıştırıp "
                f"pubspec.lock'u commit'leyin)."
            )


def kontrol_gevsek_kisitlar() -> None:
    """Bir ana sürümü aşan bağımlılık aralıkları uyarılır.

    `>=0.5.2 <1.0.0` gibi geniş bir aralık, kod belirli bir API'ye göre
    yazılmışken çözücünün başka bir sürüm seçmesine izin veriyor.
    0.7.8'de derleme tam da bu yüzden kırıldı.
    """
    metin = PUBSPEC.read_text(encoding="utf-8")
    bolum = re.search(r"^dependencies:\s*$(.*?)^\S", metin, re.M | re.S)
    if not bolum:
        return

    for satir in bolum.group(1).splitlines():
        eslesme = re.match(r"^  ([a-z_][a-z0-9_]*):\s*(['\"]?)(>=[^'\"]+)\2\s*$", satir)
        if eslesme:
            hata(
                f"`{eslesme.group(1)}` kısıtı geniş: {eslesme.group(3)}. "
                f"Kod belirli bir API'ye göre yazılıyken çözücü başka bir "
                f"sürüm seçebilir; `^X.Y.Z` kullanın."
            )


def main() -> None:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        raise SystemExit(1)

    etiket = sys.argv[1]
    surum, yapi = pubspec_surumu()
    print(f"Etiket: {etiket} | pubspec: {surum}+{yapi}")

    kontrol_surum_eslesmesi(etiket, surum)
    kontrol_yapi_numarasi(yapi, etiket)
    kontrol_kilit_dosyasi()
    kontrol_gevsek_kisitlar()

    if hatalar:
        print("\nSürüm ön kontrolü BAŞARISIZ:\n", file=sys.stderr)
        for h in hatalar:
            print(f"  • {h}", file=sys.stderr)
        raise SystemExit(1)

    print("Sürüm ön kontrolü tamam.")


if __name__ == "__main__":
    main()
