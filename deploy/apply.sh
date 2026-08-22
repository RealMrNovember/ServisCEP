#!/usr/bin/env bash
# ServisCEP — deploy uygulama adımı.
#
# deploy.sh tarafından, git pull TAMAMLANDIKTAN SONRA taze bir process
# olarak çağrılır. Doğrudan çalıştırılabilir ama normalde deploy.sh
# üzerinden tetiklenir.

set -euo pipefail

SITE_DIR="/www/wwwroot/serviscep.cicibyte.com"
cd "$SITE_DIR"

echo "==> Placeholder / statik dosyalar güncelleniyor"
cp -f deploy/public-placeholder/index.html index.html
cp -f deploy/public-placeholder/privacy.html privacy.html
cp -f deploy/public-placeholder/account-deletion.html account-deletion.html
cp -f deploy/public-placeholder/robots.txt robots.txt
cp -f deploy/public-placeholder/favicon.ico favicon.ico
cp -f deploy/public-placeholder/apple-touch-icon.png apple-touch-icon.png
cp -f deploy/public-placeholder/logo.png logo.png

# ── Backend (Laravel + Filament + mobil API) — canlıya alındı (2026-08-21) ──
# PHP çalışma zamanı 2026-08-22'den itibaren Docker'da (serviscep-php,
# bkz. /www/dk_project/serviscep) — composer/artisan artık host'un php'si
# yerine AYNI image üzerinden, container içinde çalışır. Site dizini
# container'a aynı yoldan bind-mount edildiği için "docker exec" burada
# host'taki host içinde çalışıyormuş gibi davranır.
if [ -f backend/artisan ]; then
  echo "==> Composer bağımlılıkları"
  docker exec serviscep-php composer install --no-dev --optimize-autoloader

  echo "==> Migration"
  docker exec serviscep-php php artisan migrate --force

  echo "==> Config/route/view cache"
  docker exec serviscep-php php artisan config:cache
  docker exec serviscep-php php artisan route:cache
  docker exec serviscep-php php artisan view:cache

  echo "==> Storage symlink"
  docker exec serviscep-php php artisan storage:link || true
fi

echo "==> İzinler ayarlanıyor (yalnızca repo dosyaları — aaPanel'in yönettiği"
echo "    .user.ini / .well-known gibi dosyalara dokunulmaz)"
git ls-files -z | xargs -0 -r chown www:www
chown www:www index.html robots.txt favicon.ico apple-touch-icon.png logo.png .gitignore 2>/dev/null || true
chown -R www:www .git 2>/dev/null || true

echo "==> Deploy tamamlandı: $(git rev-parse --short HEAD)"
