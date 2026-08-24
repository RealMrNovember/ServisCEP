"""CHANGELOG.md'den Play Store 'Yenilikler' metnini üretir.

Kullanım:  python3 .github/scripts/prepare_release_notes.py v0.5.0

Sürüm notu yazmak ZORUNLUDUR (kullanıcı kararı, 2026-08-24): bölüm yoksa,
boşsa, bozuksa veya 500 karakteri aşıyorsa betik hata verir ve CI sürümü
yayınlamaz.

Mantık bilerek ayrı bir dosyada: workflow içine gömülü heredoc hem YAML
girintisini bozuyor hem de yerelde test edilemiyor. Bu dosyayı doğrudan
çalıştırıp çıktıyı görebilirsiniz.
"""

from __future__ import annotations

import pathlib
import re
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
CHANGELOG = REPO_ROOT / "CHANGELOG.md"
OUTPUT = REPO_ROOT / "mobile" / "whatsnew" / "whatsnew-tr-TR"

PLAY_LIMIT = 500
REPLACEMENT_CHAR = "�"


def fail(message: str) -> None:
    print(f"HATA: {message}", file=sys.stderr)
    raise SystemExit(1)


def extract(version: str) -> str:
    if not CHANGELOG.exists():
        fail(f"{CHANGELOG} bulunamadı.")

    raw = CHANGELOG.read_bytes()
    try:
        content = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        fail(f"CHANGELOG.md geçerli UTF-8 değil: {exc}")

    match = re.search(
        rf"^## {re.escape(version)}\s*\n(.*?)(?=^## |\Z)",
        content,
        re.S | re.M,
    )
    if not match:
        fail(
            f"CHANGELOG.md içinde '## {version}' bölümü yok.\n"
            "       Her sürümde kullanıcıya görünecek notu yazmak zorunludur."
        )

    body = "\n".join(line.rstrip() for line in match.group(1).splitlines() if line.strip())

    if not body:
        fail(f"'## {version}' bölümü boş.")
    if REPLACEMENT_CHAR in body:
        fail("Metinde bozuk karakter (U+FFFD) var — kodlama bir yerde bozulmuş.")
    if len(body) > PLAY_LIMIT:
        fail(f"Sürüm notu {len(body)} karakter — Play Store sınırı {PLAY_LIMIT}.")

    return body


def main() -> None:
    if len(sys.argv) != 2:
        fail("Sürüm etiketi verilmedi. Örnek: prepare_release_notes.py v0.5.0")

    version = sys.argv[1]
    body = extract(version)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(body, encoding="utf-8")

    # Konsol kodlaması (ör. Windows cp1254) metni basamayabilir — bu bir
    # bozulma DEĞİLDİR, yalnızca görüntüdür. Bu yüzden çıktıyı basarken
    # hata almamak için değiştirilebilir kodlama kullanılıyor.
    sys.stdout.reconfigure(errors="replace")
    print(f"{OUTPUT.relative_to(REPO_ROOT)} yazıldı ({len(body)} karakter)")
    print("--- Play'de görünecek metin ---")
    print(body)


if __name__ == "__main__":
    main()
