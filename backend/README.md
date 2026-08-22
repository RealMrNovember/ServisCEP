# TeknikCEP — Backend (Laravel + Filament + Mobil API)

İki katman aynı Laravel uygulamasında birlikte yaşar: **Filament tabanlı web/admin paneli** (şirket paneli `/panel`, admin paneli `/admin`) ve **mobil için JSON REST API** (`/api/v1/*`, Sanctum token). İkisi de aynı veri modelini (Company/Customer/Job/...) kullanır — bkz. [../docs/13](../docs/13-web-arayuzu-ve-showroom.md).

> **Durum:** Production'da canlı (`serviscep.cicibyte.com`). Web paneli olgun; mobil REST API 2026-08-21'de eklenmeye başlandı (Auth + Customer, bkz. [../ROADMAP.md](../ROADMAP.md) § Backend Mimarisi — Güncel Durum). PHP çalışma zamanı 2026-08-22'den itibaren production'da **Docker'da** (`serviscep-php`, bkz. § Production Runtime aşağıda) — yerel geliştirme akışı bu bölümdeki adımlarla aynı kalır, değişen sadece sunucudaki dağıtım şeklidir.

## Kurulum

```bash
composer install
cp .env.example .env
php artisan key:generate
```

`.env` içinde veritabanı bağlantısını doldurun (PostgreSQL — bkz. [deploy/README.md](../deploy/README.md#ortam)). Yerel geliştirmede sunucudaki veritabanına SSH tüneli ile bağlanılabilir (SSH portu 6466'ya taşındı — bkz. `~/.ssh/config`'teki `cicibyte` host'u):

```bash
ssh -N -L 5434:127.0.0.1:5434 cicibyte
```

Sonra:

```bash
php artisan migrate
php artisan serve
```

## PHP/Composer Kurulu Değilse (Docker ile)

Yerel makinede PHP/Composer yoksa, `composer:2` imajı (PHP CLI + Composer birlikte) hiçbir şey kurmadan aynı işi görür — PowerShell'den proje kökünden çalıştırılır. Filament `ext-intl` gerektirir, imajda yok — `--ignore-platform-req` ile atlanabilir (yalnızca API/backend testleri için sorun değil, Filament panellerini bu şekilde çalıştırmayın):

```powershell
docker run --rm -v "C:\CiciByte\ServisCEP\backend:/app" -w /app composer:2 composer install --ignore-platform-req=ext-intl
docker run --rm --entrypoint php -v "C:\CiciByte\ServisCEP\backend:/app" -w /app composer:2 artisan key:generate
docker run --rm --entrypoint php -v "C:\CiciByte\ServisCEP\backend:/app" -w /app composer:2 artisan test
```

Testler `phpunit.xml` üzerinden SQLite in-memory veritabanı kullanır. (Not: Docker Desktop bu ortamda yalnızca **PowerShell**'den erişilebiliyor; Git Bash/WSL üzerinden `docker` komutları named pipe hatası verebilir.)

## Production Runtime (Docker)

Sunucuda PHP çalışma zamanı `/www/dk_project/serviscep/` altındaki `Dockerfile` + `docker-compose.yml` ile tanımlı (`serviscep-php` container'ı, `php:8.4-fpm-alpine`, diğer sunucu projeleriyle aynı aaPanel Docker kalıbı). Nginx (host'ta, aaPanel yönetiminde) `fastcgi_pass 127.0.0.1:9102` ile bu container'a bağlanır — SSL/Cloudflare çözümü nginx'te kalmaya devam eder, yalnızca PHP execution container'a taşındı.

**Kritik detaylar:**
- Container `33:33` (www-data) kullanıcısıyla çalışır — bu sitenin `storage/`/`bootstrap/cache/` sahipliği `www-data`'dır (diğer sitelerin `www:www` kalıbından **farklı**, karıştırılmamalı).
- Postgres bare-metal kalır (containerize edilmedi); container'a erişim `extra_hosts: host.docker.internal:host-gateway` + `.env`'de `DB_HOST=host.docker.internal` ile sağlanır. Bunun çalışması için host'ta `listen_addresses='*'` (yalnızca bu Postgres örneği, port 5434, başka veritabanı barındırmıyor), dar kapsamlı bir `pg_hba.conf` satırı (`172.30.90.0/24` + `serviscep_app` kullanıcısı) ve bir UFW kuralı (`ufw allow from 172.30.90.0/24 to any port 5434 proto tcp`) gerekti — hepsi uygulandı ve doğrulandı (2026-08-22).
- `deploy/apply.sh` artık composer/artisan komutlarını `docker exec serviscep-php ...` ile container içinde çalıştırır; sunucudaki crontab da `customers:purge-trash` için aynı kalıbı kullanır (`docker exec serviscep-php php artisan schedule:run`).
- **Operasyonel not:** `serviscep.cicibyte.com` sitesinin PHP sürümü aaPanel panelinden değiştirilirse, panel nginx vhost'unu yeniden yazıp `fastcgi_pass`'i eski unix socket'e döndürebilir — bu durumda satırı tekrar `127.0.0.1:9102`'ye çevirmek gerekir.

## Kalıcı Kural: Migration'lar

Production'da **zaten çalıştırılmış** bir migration dosyası asla düzenlenmez (`php artisan migrate` onu atlar, değişiklik hiçbir yere ulaşmaz). Şema düzeltmesi her zaman **yeni bir migration** ile yapılır — örnek: [2026_08_21_100001_fix_personal_access_tokens_tokenable_id_to_uuid.php](database/migrations/2026_08_21_100001_fix_personal_access_tokens_tokenable_id_to_uuid.php).

## Uyulması Gereken Dokümanlar

- Katman yapısı ve business logic yerleşimi (`app/Services`, `app/Actions`, `app/Policies`): [../docs/06-teknik-mimari.md](../docs/06-teknik-mimari.md#7-backend-yapısı-laravel)
- API tasarım prensipleri ve response standardı: [../docs/07-api-ve-veritabani.md](../docs/07-api-ve-veritabani.md)
- Güvenlik ve yetkilendirme kuralları: [../docs/09-guvenlik-ve-yetkilendirme.md](../docs/09-guvenlik-ve-yetkilendirme.md)
- Cari hesap veri modeli: [../docs/15-cari-hesap.md](../docs/15-cari-hesap.md)
- Para/finans hesaplama kuralı: [../docs/04-finans-ve-stok.md](../docs/04-finans-ve-stok.md#para-hesaplama-kuralı-kritik--teknik-zorunluluk)
- Genel geliştirme prensipleri: [../docs/11-gelistirme-prensipleri.md](../docs/11-gelistirme-prensipleri.md)
