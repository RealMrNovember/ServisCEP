#!/bin/bash
# TeknikCEP günlük yedeği — veritabanı + saha dosyaları.
#
# NEDEN AYRI BİR BETİK: sunucudaki docker-db-backup.sh yalnızca Docker
# container'ı olarak çalışan Postgres'leri buluyor. TeknikCEP'in Postgres'i
# çıplak kurulu (port 5434), dolayısıyla o taramaya HİÇ girmiyordu —
# yani bu veritabanının yedeği yoktu.
#
# NEREYE YAZIYOR: /www/backup/docker-dbs. Bilinçli tercih. O dizin zaten
# aaPanel görevine bağlı ve gdrive-upload-dbs.py ile her gece Drive'a
# gidiyor. Kendi dizinimize yazsaydık yedek SUNUCUDA kalırdı; sunucuyu
# kaybettiğimizde yedeği de kaybederdik.
#
# ZAMANLAMA: 02:30. Yükleyici 02:45'te çalışıyor — aynı gece Drive'a
# çıkabilmesi için ondan ÖNCE bitmeli.
#
# NOT: .env yedeklenmiyor. İçinde APP_KEY var ve APP_KEY, şifreli
# sütunları (ör. ödeme sağlayıcı anahtarları) çözen tek şey. Bunu Drive'a
# göndermek, veriyle birlikte anahtarı da aynı sepete koymak olurdu.
# APP_KEY ayrıca ve elle saklanmalı — bkz. deploy/README.md.
set -uo pipefail

# Alan adı ve dizin adı hâlâ "serviscep": marka TeknikCEP olarak
# değişti ama teknik tanımlayıcılar bilinçli olarak korundu.
KAYNAK_DIZIN=/www/wwwroot/serviscep.cicibyte.com/backend
PG_PORT=5434
HEDEF=/www/backup/docker-dbs
GUNLUK=/var/log/teknikcep-yedek.log
SAKLAMA_GUN=7
TARIH=$(date +%Y%m%d-%H%M)

# postgres kullanıcısının okuyamadığı bir dizinden çalışırsak pg_dump her
# gece günlüğe "could not change directory" yazar — gerçek hatayı gömen
# gürültü. Herkesin okuyabildiği bir dizine geçiyoruz.
cd /tmp || exit 1

yaz() { echo "$(date '+%F %T') $1" >> "$GUNLUK"; }

# Sessiz başarısızlık bir yedekleme sisteminin en kötü hâlidir: aylarca
# "yedek var" sanılır, gereken gün boş çıkar. Hata Telegram'a düşer.
uyar() {
    yaz "HATA: $1"
    local env_dosya=/www/wwwroot/cicibyte.com/.env
    [ -r "$env_dosya" ] || return 0
    local jeton sohbet
    jeton=$(grep '^TELEGRAM_BOT_TOKEN=' "$env_dosya" | cut -d= -f2- | tr -d '"'"'"'')
    sohbet=$(grep '^TELEGRAM_CHAT_ID=' "$env_dosya" | cut -d= -f2- | tr -d '"'"'"'')
    [ -n "$jeton" ] && [ -n "$sohbet" ] || return 0
    curl -s -m 15 -X POST "https://api.telegram.org/bot${jeton}/sendMessage" \
        -d "chat_id=${sohbet}" \
        -d "text=🔴 TeknikCEP yedeği başarısız: $1" >/dev/null || true
}

mkdir -p "$HEDEF"

# --- Restore testi ------------------------------------------------------
# "Yedek alındı" ile "yedek ÇALIŞIYOR" aynı şey değil. Sunucudaki aylık
# backup-restore-test.sh dört başka projeye hizmet ediyor; oraya bir satır
# eklemek yerine doğrulama burada duruyor — kendi yedeğimizin sağlığı
# başka bir projenin betiğine bağlı olmamalı.
#
# En son dump'ı boş bir Postgres container'ına gerçekten geri yükler ve
# kayıt sayar. Ayın 1'inde cron ile çalışır.
if [ "${1:-}" = "--restore-testi" ]; then
    DUMP=$(ls -t "$HEDEF"/teknikcep-db-*.sql.gz 2>/dev/null | head -1)
    [ -n "$DUMP" ] || { uyar "restore testi: dump dosyası yok"; exit 1; }

    KAP=teknikcep-restore-testi
    docker rm -f "$KAP" >/dev/null 2>&1 || true
    # Kaynakla AYNI ana sürüm. Daha yeni bir Postgres eski dump'ı genelde
    # açar, ama "genelde" bir yedekleme güvencesi değildir.
    docker run -d --name "$KAP" -e POSTGRES_PASSWORD=gecici postgres:14-alpine >/dev/null 2>&1

    hazir=0
    for _ in $(seq 1 40); do
        if docker exec "$KAP" pg_isready -q -U postgres 2>/dev/null; then
            # Postgres ilk açılışta bir kez yeniden başlıyor; tek bir
            # pg_isready erken "hazır" diyebiliyor.
            sleep 3
            docker exec "$KAP" pg_isready -q -U postgres 2>/dev/null && { hazir=1; break; }
        fi
        sleep 2
    done
    [ "$hazir" = "1" ] || { docker rm -f "$KAP" >/dev/null 2>&1; uyar "restore testi: container hazır olmadı"; exit 1; }

    zcat "$DUMP" | docker exec -i "$KAP" psql -q -U postgres >/dev/null 2>>"$GUNLUK"

    SIRKET=$(docker exec "$KAP" psql -tA -U postgres -d serviscep         -c "SELECT count(*) FROM companies" 2>/dev/null || echo 0)
    docker rm -f "$KAP" >/dev/null 2>&1 || true

    # Şirket sayısı: tablo sayısı yapıyı doğrular, VERİYİ doğrulamaz.
    # Şema restore edilip satırların gelmediği bir dump da "38 tablo" der.
    if [ "${SIRKET:-0}" -gt 0 ]; then
        yaz "restore testi OK: ${SIRKET} şirket geri yüklendi ($(basename "$DUMP"))"
        exit 0
    fi
    uyar "restore testi BAŞARISIZ: yedek açıldı ama şirket kaydı yok"
    exit 1
fi

# --- Veritabanı ---------------------------------------------------------
# peer kimlik doğrulaması: parola betikte durmasın diye postgres kullanıcısı
# üzerinden alınıyor.
DB_CIKTI="$HEDEF/teknikcep-db-${TARIH}.sql.gz"
# pg_dumpall, pg_dump değil. Bu örnek yalnızca TeknikCEP'in veritabanını
# barındırıyor, dolayısıyla kapsam aynı; ama çıktı CREATE DATABASE ve rol
# tanımlarını da içeriyor. Aylık restore testi (backup-restore-test.sh)
# dump'ı boş bir container'a "psql -U postgres" ile basıp veritabanlarını
# sayıyor — tek-DB dump'ı `postgres` veritabanının içine açılır ve o
# sayımdan dışlanır, yani ÇALIŞAN bir yedek "tablo yok" diye rapor edilirdi.
if sudo -u postgres pg_dumpall -p "$PG_PORT" --clean 2>>"$GUNLUK" \
   | gzip > "$DB_CIKTI" && [ -s "$DB_CIKTI" ]; then
    yaz "OK: veritabanı -> $(basename "$DB_CIKTI") ($(du -h "$DB_CIKTI" | cut -f1))"
else
    rm -f "$DB_CIKTI"
    uyar "veritabanı dump'ı alınamadı"
    exit 1
fi

# gzip bütünlüğü: bozuk bir arşiv, dosya var diye yedek sayılır ve gereken
# gün açılmaz.
if ! gzip -t "$DB_CIKTI" 2>>"$GUNLUK"; then
    rm -f "$DB_CIKTI"
    uyar "dump bozuk (gzip doğrulaması geçmedi)"
    exit 1
fi

# Dump'ın GERÇEKTEN veri içerdiğini doğrula. Boş ama geçerli bir gzip,
# yukarıdaki iki kontrolü de geçer.
TABLO_SAYISI=$(gunzip -c "$DB_CIKTI" | grep -c '^CREATE TABLE' || true)
if [ "$TABLO_SAYISI" -lt 10 ]; then
    uyar "dump şüpheli: yalnızca ${TABLO_SAYISI} tablo bulundu"
    exit 1
fi
yaz "doğrulandı: ${TABLO_SAYISI} tablo"

# --- Saha dosyaları -----------------------------------------------------
# İş fotoğrafları ve müşteri imzaları. Veritabanı bunlara yalnızca yol
# tutuyor; dosyalar gitse kayıtlar kırık yola işaret eder.
#
# service-account.json hariç: kimlik bilgisi, veri değil (bkz. APP_KEY notu).
DOSYA_CIKTI="$HEDEF/teknikcep-dosyalar-${TARIH}.tar.gz"
if tar -czf "$DOSYA_CIKTI" \
       --exclude='firebase' \
       -C "$KAYNAK_DIZIN/storage" app 2>>"$GUNLUK" && [ -s "$DOSYA_CIKTI" ]; then
    yaz "OK: dosyalar -> $(basename "$DOSYA_CIKTI") ($(du -h "$DOSYA_CIKTI" | cut -f1))"
else
    rm -f "$DOSYA_CIKTI"
    uyar "saha dosyaları arşivlenemedi"
    exit 1
fi

# --- Temizlik -----------------------------------------------------------
find "$HEDEF" -name 'teknikcep-*' -mtime +$SAKLAMA_GUN -delete

yaz "tamamlandı"
exit 0
