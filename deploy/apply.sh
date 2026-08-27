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

# Uzantısız adresler de çalışsın: /privacy ve /account-deletion.
#
# Play Console'a verilen adresler uzantısız ("…/privacy") ama sunucu
# yalnızca "privacy.html" servis ediyordu; ikisi de 404 dönüyordu ve
# Google, çalışmayan bir gizlilik politikası bağlantısını politika
# ihlali sayıyor.
#
# Dizinler DOCROOT'a açılıyor (backend/public), site köküne değil:
# nginx'in kökü orası ve buradaki statik dosyalar oraya elle kurulmuş
# sembolik linklerle bağlı. Site köküne açılan bir dizin hiç servis
# edilmiyor — ilk denemede bu yaşandı.
#
# Çözüm nginx yapılandırmasında DEĞİL: vhost aaPanel tarafından
# yönetiliyor ve sitenin PHP sürümü panelden değiştirilirse elle eklenen
# yönlendirme sessizce siliniyor. Dizin + index.html her nginx
# yapılandırmasında çalışır. Uzantılı adresler de duruyor — daha önce
# paylaşılmış bağlantılar kırılmasın.
if [ -d backend/public ]; then
  for sayfa in privacy account-deletion; do
    mkdir -p "backend/public/$sayfa"
    cp -f "deploy/public-placeholder/$sayfa.html" "backend/public/$sayfa/index.html"
  done
fi

# ── Backend (Laravel + Filament + mobil API) — canlıya alındı (2026-08-21) ──
# PHP çalışma zamanı 2026-08-22'den itibaren Docker'da (serviscep-php,
# bkz. /www/dk_project/serviscep) — composer/artisan artık host'un php'si
# yerine AYNI image üzerinden, container içinde çalışır. Site dizini
# container'a aynı yoldan bind-mount edildiği için "docker exec" burada
# host'taki host içinde çalışıyormuş gibi davranır.
if [ -f backend/artisan ]; then
  echo "==> Composer bağımlılıkları"
  # root olarak çalıştırılır: vendor/ önceki (container-öncesi) deploy'lardan
  # kalma root sahipliğinde olabilir, container'ın normal kullanıcısı
  # (www-data, uid 33) bunun üzerine yazamaz. FPM süreci hâlâ www-data
  # olarak çalışmaya devam eder (compose'daki user: "33:33" değişmedi) —
  # yalnızca bu tek seferlik composer adımı root'a yükseltilir.
  docker exec -u root serviscep-php composer install --no-dev --optimize-autoloader
  docker exec -u root serviscep-php chown -R www-data:www-data vendor

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
