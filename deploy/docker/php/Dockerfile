# TeknikCEP — PHP çalışma zamanı (production + test).
#
# ÖNEMLİ: Bu dosya production'da `/www/dk_project/serviscep/Dockerfile`
# olarak kullanılan imajın KAYNAĞIDIR. Daha önce yalnızca sunucuda
# duruyordu; sunucu kaybedilirse yeniden üretilemez bir bilgi olduğu için
# repoya alındı (2026-08-25).
#
# Sunucuda değişiklik yapılırsa buraya da yansıtılmalı — iki kopya
# ayrışırsa production'ın nasıl kurulduğu bilinmez hâle gelir.
#
# Testler de bu imajla çalıştırılmalıdır: `composer:2` imajında `intl`
# eklentisi YOK ve Filament sayfaları onsuz render edilemiyor. Bu yüzden
# admin panel testleri o imajda sessizce çalıştırılamıyordu.
# Bkz. backend/README.md § Testler.
FROM php:8.4-fpm-alpine

# mlocati/docker-php-extension-installer — Alpine paket adlarıyla elle
# uğraşmak yerine güvenilir, bağımlılıkları kendi çözen kurulum yöntemi.
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN install-php-extensions pdo_pgsql pgsql intl bcmath gd opcache zip mbstring exif

# Opcache production ayarları — cicibyte-php ile aynı kalıp.
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.max_accelerated_files=10000'; \
    echo 'opcache.validate_timestamps=1'; \
    echo 'opcache.revalidate_freq=2'; \
    } > /usr/local/etc/php/conf.d/opcache.ini

# composer/artisan CLI (deploy + cron) da AYNI image'dan çalışsın diye.
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /www/wwwroot/serviscep.cicibyte.com/backend
