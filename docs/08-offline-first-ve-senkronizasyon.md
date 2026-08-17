# 08 — Offline-First ve Senkronizasyon

> Kaynak: orijinal spesifikasyon §33–§34, §66–§67.
>
> ⚠️ **Bu mimari, proje için kritik bir gereksinimdir** — atlanabilir/ertelenebilir bir özellik değildir.

## Neden Offline-First?

Saha ortamında (bodrum, asansör boşluğu, kırsal alan, kalabalık AVM vb.) internet bağlantısı **olmayabilir veya kesintili olabilir.** Bu nedenle kullanıcı, internet olmadan aşağıdaki işlemlerin **tamamını** yapabilmelidir:

- Müşteri oluşturmak
- İş oluşturmak
- Servis formu doldurmak
- Fotoğraf çekmek
- Not yazmak
- Tahsilat kaydetmek

Bu, "bazı ekranlar offline çalışır" değil, **saha operasyonunun tamamının offline çalışması** gerektiği anlamına gelir.

## Genel Akış

Veriler önce lokal veritabanına kaydedilir. İnternet bağlantısı geldiğinde otomatik senkronizasyon devreye girer:

```
LOCAL
  ↓
SYNC QUEUE
  ↓
API
  ↓
SERVER
```

## Senkronizasyon Durum Makinesi

Her lokal işlem şu durumlardan birinde tutulur:

| Durum | Anlamı |
|---|---|
| `PENDING` | Henüz sunucuya gönderilmedi |
| `SYNCED` | Sunucuya başarıyla gönderildi ve onaylandı |
| `FAILED` | Gönderim başarısız oldu, yeniden denenecek |

> **UX kuralı:** Kullanıcıya teknik hata mesajı (stack trace, HTTP status kodu vb.) **gösterilmemelidir.** Bunun yerine sade, anlaşılır bir bilgi gösterilmelidir:
>
> *"3 kayıt senkronizasyon bekliyor."*

## Lokal Veritabanı

Mobil tarafta offline veri için yerel bir veritabanı kullanılmalıdır. Önerilen minimum tablo kapsamı:

```
customers
jobs
service_requests
quotes
proformas
payments
incomes
expenses
sync_queue
```

## Sync Conflict (Çakışma) Yönetimi

Aynı kayıt, farklı cihazlardan (ör. iki teknisyen aynı müşteri kaydını güncellerse) değiştirilirse sistem bir **conflict** durumu oluşturmalıdır.

**İlk sürüm (MVP) yaklaşımı — temel conflict detection:**

```
server_updated_at
local_updated_at
version
```

alanları karşılaştırılarak çakışma tespit edilir.

> ⚠️ **Kritik kural:** Çakışmalı bir kayıt **otomatik olarak sessizce ezilemez.** Kullanıcıya (veya en azından audit log'a) çakışmanın varlığı yansıtılmalı, veri kaybı sessizce gerçekleşmemelidir.

## İlişkili Dokümanlar

- Veritabanı ana modeli: [07 — API ve Veritabanı](07-api-ve-veritabani.md)
- "Gerçek hayat" offline test senaryosu (MVP kabul kriteri): [11 — Geliştirme Prensipleri § Gerçek Hayat Test Senaryosu](11-gelistirme-prensipleri.md#gerçek-hayat-test-senaryosu)
