#!/usr/bin/env bash
# ServisCEP — sunucu üzerinde çalıştırılan deploy scripti (pull adımı).
#
# Kullanım (sunucuda, site dizininde):
#   bash deploy/deploy.sh
#
# Bu script şu ana kadar SADECE bu sitenin dizinine dokunur
# (/www/wwwroot/serviscep.cicibyte.com). Başka hiçbir site/servis
# etkilenmez.
#
# NOT: Bu script git pull ile KENDİSİNİ günceller. Bu nedenle asıl
# deploy mantığı burada değil, pull tamamlandıktan SONRA taze bir
# process ile çalıştırılan deploy/apply.sh içindedir — aksi halde
# çalışan process, güncellenmeden önceki eski script içeriğini
# yürütmeye devam edebilir (self-modifying script sorunu).

set -euo pipefail

SITE_DIR="/www/wwwroot/serviscep.cicibyte.com"
BRANCH="main"

cd "$SITE_DIR"

echo "==> En son kod çekiliyor ($BRANCH)"
git fetch origin "$BRANCH"
git reset --hard "origin/$BRANCH"

echo "==> apply.sh taze bir process olarak çalıştırılıyor"
exec bash "$SITE_DIR/deploy/apply.sh"
