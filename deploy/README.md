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

## Backend Devreye Girdiğinde Yapılacaklar (Phase 3+)

- nginx `root` yönergesi `/www/wwwroot/serviscep.cicibyte.com` yerine `/www/wwwroot/serviscep.cicibyte.com/backend/public` olarak güncellenmelidir (yalnızca bu sitenin nginx conf dosyası değişir).
- `backend/.env` dosyası, sunucudaki veritabanı kimlik bilgileriyle (root-only saklanan dosyadan) doldurulmalıdır — bu dosya **asla** git'e commitlenmez (`.gitignore` içinde zaten hariç tutulmuştur).
- `deploy.sh` içindeki yorumlanmış composer/artisan adımları etkinleştirilmelidir.
