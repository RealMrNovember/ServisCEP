# ServisCEP — Backend (Laravel + Filament + Mobil API)

İki katman aynı Laravel uygulamasında birlikte yaşar: **Filament tabanlı web/admin paneli** (şirket paneli `/panel`, admin paneli `/admin`) ve **mobil için JSON REST API** (`/api/v1/*`, Sanctum token). İkisi de aynı veri modelini (Company/Customer/Job/...) kullanır — bkz. [../docs/13](../docs/13-web-arayuzu-ve-showroom.md).

> **Durum:** Production'da canlı (`serviscep.cicibyte.com`). Web paneli olgun; mobil REST API 2026-08-21'de eklenmeye başlandı (Auth + Customer, bkz. [../ROADMAP.md](../ROADMAP.md) § Backend Mimarisi — Güncel Durum).

## Kurulum

```bash
composer install
cp .env.example .env
php artisan key:generate
```

`.env` içinde veritabanı bağlantısını doldurun (PostgreSQL — bkz. [deploy/README.md](../deploy/README.md#ortam)). Yerel geliştirmede sunucudaki veritabanına SSH tüneli ile bağlanılabilir:

```bash
ssh -N -L 5434:127.0.0.1:5434 root@31.40.199.47
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

## Kalıcı Kural: Migration'lar

Production'da **zaten çalıştırılmış** bir migration dosyası asla düzenlenmez (`php artisan migrate` onu atlar, değişiklik hiçbir yere ulaşmaz). Şema düzeltmesi her zaman **yeni bir migration** ile yapılır — örnek: [2026_08_21_100001_fix_personal_access_tokens_tokenable_id_to_uuid.php](database/migrations/2026_08_21_100001_fix_personal_access_tokens_tokenable_id_to_uuid.php).

## Uyulması Gereken Dokümanlar

- Katman yapısı ve business logic yerleşimi (`app/Services`, `app/Actions`, `app/Policies`): [../docs/06-teknik-mimari.md](../docs/06-teknik-mimari.md#7-backend-yapısı-laravel)
- API tasarım prensipleri ve response standardı: [../docs/07-api-ve-veritabani.md](../docs/07-api-ve-veritabani.md)
- Güvenlik ve yetkilendirme kuralları: [../docs/09-guvenlik-ve-yetkilendirme.md](../docs/09-guvenlik-ve-yetkilendirme.md)
- Cari hesap veri modeli: [../docs/15-cari-hesap.md](../docs/15-cari-hesap.md)
- Para/finans hesaplama kuralı: [../docs/04-finans-ve-stok.md](../docs/04-finans-ve-stok.md#para-hesaplama-kuralı-kritik--teknik-zorunluluk)
- Genel geliştirme prensipleri: [../docs/11-gelistirme-prensipleri.md](../docs/11-gelistirme-prensipleri.md)
