# ServisCEP — Backend (Laravel API)

Laravel tabanlı REST API. Mobil ve web arayüzü aynı API'yi tüketir (bkz. [../docs/13](../docs/13-web-arayuzu-ve-showroom.md)).

> **Durum:** Phase 1 (Project Architecture) — proje iskeleti kuruldu, veritabanı bağlantısı doğrulandı. Öncelik şu anda mobil uygulamada (bkz. [../ROADMAP.md](../ROADMAP.md)); asıl API geliştirmesi Phase 3'te derinleşecek.

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

## Uyulması Gereken Dokümanlar

- Katman yapısı ve business logic yerleşimi (`app/Services`, `app/Actions`, `app/Policies`): [../docs/06-teknik-mimari.md](../docs/06-teknik-mimari.md#7-backend-yapısı-laravel)
- API tasarım prensipleri ve response standardı: [../docs/07-api-ve-veritabani.md](../docs/07-api-ve-veritabani.md)
- Güvenlik ve yetkilendirme kuralları: [../docs/09-guvenlik-ve-yetkilendirme.md](../docs/09-guvenlik-ve-yetkilendirme.md)
- Cari hesap veri modeli: [../docs/15-cari-hesap.md](../docs/15-cari-hesap.md)
- Para/finans hesaplama kuralı: [../docs/04-finans-ve-stok.md](../docs/04-finans-ve-stok.md#para-hesaplama-kuralı-kritik--teknik-zorunluluk)
- Genel geliştirme prensipleri: [../docs/11-gelistirme-prensipleri.md](../docs/11-gelistirme-prensipleri.md)
