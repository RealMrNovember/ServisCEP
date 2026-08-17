#!/usr/bin/env bash
# ServisCEP — sunucu üzerinde çalıştırılan deploy scripti.
#
# Kullanım (sunucuda, site dizininde):
#   bash deploy/deploy.sh
#
# Bu script şu ana kadar SADECE bu sitenin dizinine dokunur
# (/www/wwwroot/serviscep.cicibyte.com). Başka hiçbir site/servis
# etkilenmez.

set -euo pipefail

SITE_DIR="/www/wwwroot/serviscep.cicibyte.com"
BRANCH="main"

cd "$SITE_DIR"

echo "==> En son kod çekiliyor ($BRANCH)"
git fetch origin "$BRANCH"
git reset --hard "origin/$BRANCH"

echo "==> Placeholder / statik dosyalar güncelleniyor"
cp -f deploy/public-placeholder/index.html index.html
cp -f deploy/public-placeholder/robots.txt robots.txt

# ── Backend (Laravel) devreye girdiğinde aşağıdaki adımlar açılacak ──
# if [ -d backend/artisan ] || [ -f backend/artisan ]; then
#   echo "==> Composer bağımlılıkları"
#   (cd backend && composer install --no-dev --optimize-autoloader)
#
#   echo "==> Migration"
#   (cd backend && php artisan migrate --force)
#
#   echo "==> Config/route/view cache"
#   (cd backend && php artisan config:cache && php artisan route:cache && php artisan view:cache)
#
#   echo "==> Storage symlink"
#   (cd backend && php artisan storage:link || true)
# fi

echo "==> İzinler ayarlanıyor"
chown -R www:www "$SITE_DIR"

echo "==> Deploy tamamlandı: $(git rev-parse --short HEAD)"
