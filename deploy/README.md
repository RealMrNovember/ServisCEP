# Deploy

TeknikCEP, `serviscep.cicibyte.com` adresinde barındırılır. Sunucu aaPanel ile yönetilen bir Ubuntu 22.04 makinedir; site dizini `/www/wwwroot/serviscep.cicibyte.com` içinde bu reponun bir git checkout'udur.

## Ortam

| Bileşen | Değer |
|---|---|
| Web sunucusu | nginx (aaPanel yönetimli, `fastcgi_pass 127.0.0.1:9102`) |
| PHP | 8.4-fpm-alpine, **Docker container'ında** (`serviscep-php`, bkz. [backend/README.md § Production Runtime](../backend/README.md#production-runtime-docker)) |
| Veritabanı | PostgreSQL 14, bare-metal, port `5434` (`serviscep` veritabanı) — container'a `host.docker.internal` + dar kapsamlı `pg_hba.conf`/UFW kuralıyla erişiliyor |
| Mail | Postfix/Dovecot (sunucuda mevcut, aaPanel Mail Server eklentisi) — `serviscep@cicibyte.com` hesabı, SMTP `mail.cicibyte.com:587` (STARTTLS, sertifika bu hostname için — `host.docker.internal` ile TLS cert uyuşmazlığı verir, kullanılmamalı) |
| SSL | Let's Encrypt (aaPanel üzerinden otomatik yenilenir) |

> **Not:** PostgreSQL, sunucudaki başka bir projenin Docker container'ı standart 5432 portunu kullandığı için otomatik olarak `5434` portuna yerleşmiştir. Bu, sunucudaki diğer projelerle hiçbir çakışma olmadığı anlamına gelir.

## Deploy Akışı

Her deploy, [`deploy.sh`](deploy.sh) scripti ile yapılır:

```bash
bash deploy/deploy.sh
```

Script:
1. `origin/main`'den en son kodu çeker (`git fetch` + `git reset --hard`)
2. Statik placeholder dosyaları günceller (backend hazır olana kadar)
3. Backend (Laravel) devreye girdiğinde: composer install, migration, cache, storage symlink adımlarını çalıştırır (şu an yorum satırı olarak script içinde hazır bekliyor)
4. Dosya sahipliğini `www:www` olarak ayarlar

Script **yalnızca kendi site dizinine dokunur** — sunucudaki başka hiçbir site veya servisi etkilemez.

## Backend Devreye Alma — Durum (2026-08-21)

Aşağıdaki adımların hepsi **tamamlandı**, backend (Filament admin+web paneli) production'da canlı:

- nginx `root` yönergesi `/www/wwwroot/serviscep.cicibyte.com/backend/public` olarak ayarlı (`/panel` ve `/admin` gerçek login sayfalarına yönleniyor).
- `backend/.env` sunucuda mevcut, gerçek PostgreSQL kimlik bilgileriyle dolu (bu dosya **asla** git'e commitlenmez).
- `deploy/apply.sh` içindeki composer/migration/cache adımları etkinleştirildi.
- Tüm migration'lar production'da çalıştırılmış durumda (bkz. `php artisan migrate:status`).

**Kalıcı kural:** Zaten production'da çalıştırılmış bir migration dosyası **asla düzenlenmez** — `php artisan migrate` onu atlar, değişiklik hiçbir yere ulaşmaz. Şema düzeltmesi gerekiyorsa her zaman **yeni bir migration** yazılır (örnek: [2026_08_21_100001_fix_personal_access_tokens_tokenable_id_to_uuid.php](../backend/database/migrations/2026_08_21_100001_fix_personal_access_tokens_tokenable_id_to_uuid.php)).

## Yedekleme

`teknikcep-yedek.sh` sunucuda `/usr/local/bin/` altında çalışır.

| Ne zaman | Ne yapar |
|---|---|
| Her gece 02:30 | Veritabanı dump'ı + saha dosyaları → `/www/backup/docker-dbs` |
| Her gece 02:45 | Mevcut `gdrive-upload-dbs.py` bu dizini Google Drive'a taşır |
| Ayın 1'i 05:00 | `--restore-testi`: son dump'ı boş bir container'a gerçekten geri yükler |

Hedef dizin bilinçli olarak paylaşılan `docker-dbs` klasörü: kendi
dizinimize yazsaydık yedek yalnızca SUNUCUDA kalırdı ve sunucuyu
kaybettiğimizde yedeği de kaybederdik.

Restore testi tablo değil **şirket sayısı** kontrol ediyor. Tablo sayısı
yapıyı doğrular, veriyi doğrulamaz — şema gelip satırların gelmediği bir
dump da "38 tablo" der.

Hatalar Telegram'a düşer. Sessizce başarısız olan bir yedekleme
sisteminin en kötü hâli: aylarca "yedek var" sanılır, gereken gün boş
çıkar.

### Yedeğin İÇİNDE OLMAYAN: APP_KEY

`.env` bilinçli olarak yedeklenmiyor — veriyle şifre çözme anahtarını aynı
sepete koymamak için. Ama bunun bir bedeli var:

**APP_KEY kaybolursa şifreli sütunlar geri getirilemez.** Ödeme sağlayıcı
anahtarları (`PaymentConfig`) veritabanında `Crypt::encryptString` ile
duruyor; anahtar olmadan bu satırlar okunamaz hâle gelir. Veritabanı
yedeği eksiksiz olsa bile.

APP_KEY sunucunun DIŞINDA, ayrıca saklanmalı (parola yöneticisi).
