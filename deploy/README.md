# Deploy

ServisCEP, `serviscep.cicibyte.com` adresinde barındırılır. Sunucu aaPanel ile yönetilen bir Ubuntu 22.04 makinedir; site dizini `/www/wwwroot/serviscep.cicibyte.com` içinde bu reponun bir git checkout'udur.

## Ortam

| Bileşen | Değer |
|---|---|
| Web sunucusu | nginx (aaPanel yönetimli) |
| PHP | 8.3 (aaPanel PHP-FPM havuzu) |
| Veritabanı | PostgreSQL 14, `127.0.0.1:5434` (yalnızca localhost, `serviscep` veritabanı) |
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
