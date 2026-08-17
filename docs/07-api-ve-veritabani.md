# 07 — API ve Veritabanı

> Kaynak: orijinal spesifikasyon §35–§36, §63–§65, §84–§85.

## 1. API Prensipleri

API şu niteliklere sahip olmalıdır:

- **RESTful**
- **Versioned** (`/api/v1/...`)
- **JSON**
- **Authenticated**
- **Validated**
- **Paginated**

### Örnek Endpointler

```
/api/v1/auth/login
/api/v1/customers
/api/v1/jobs
/api/v1/service-requests
/api/v1/quotes
/api/v1/proformas
/api/v1/payments
/api/v1/incomes
/api/v1/expenses
```

## 2. API Response Standardı

**Başarılı response:**

```json
{
  "success": true,
  "data": {},
  "message": null
}
```

**Hata response:**

```json
{
  "success": false,
  "data": null,
  "message": "İşlem gerçekleştirilemedi.",
  "errors": {}
}
```

Tüm endpointler bu zarfı (envelope) tutarlı şekilde kullanmalıdır — mobil istemci tek bir response-parsing katmanı yazabilmelidir.

## 3. Pagination

Liste endpointleri her zaman pagination desteklemelidir:

```
GET /api/v1/customers?page=1&per_page=20
```

Sunucu, istemciye gereksiz miktarda veri döndürmemelidir.

## 4. Veritabanı Ana Modeli

```
users, companies, company_settings

customers, customer_addresses, customer_contacts

service_requests, jobs, job_notes, job_photos, job_materials, job_signatures

quotes, quote_items

proformas, proforma_items

invoices, invoice_items

payments, income, expenses

products, stock_movements

documents, document_templates

appointments, reminders

audit_logs, sync_operations
```

### Domain Gruplaması

| Grup | Tablolar |
|---|---|
| Kimlik / Şirket | `users`, `companies`, `company_settings` |
| Müşteri | `customers`, `customer_addresses`, `customer_contacts` |
| İş / Servis | `service_requests`, `jobs`, `job_notes`, `job_photos`, `job_materials`, `job_signatures` |
| Belge — Ticari | `quotes`, `quote_items`, `proformas`, `proforma_items`, `invoices`, `invoice_items` |
| Finans | `payments`, `income`, `expenses` |
| Stok | `products`, `stock_movements` |
| Belge Yönetimi | `documents`, `document_templates` |
| Zamanlama | `appointments`, `reminders` |
| Sistem | `audit_logs`, `sync_operations` |

## 5. Şirket Bazlı Veri Ayrımı (Multi-Tenancy)

> ⚠️ **Bu, sistemin temel güvenlik prensibidir.**

Sistem SaaS'a dönüşeceği için tüm işletme verileri `company_id` ile ayrılmalıdır. Bir şirket, **kesinlikle**:

- Başka şirketin müşterisini
- Başka şirketin işini
- Başka şirketin finansını
- Başka şirketin belgelerini

görememelidir. Bu izolasyon, uygulama kodunun her katmanında (query scope, policy, resource serialization) tutarlı şekilde uygulanmalıdır — herhangi bir sorguda `company_id` filtresinin atlanması, kritik bir güvenlik açığı sayılır.

> Yetkilendirme rolleri için bkz. [09 — Güvenlik ve Yetkilendirme](09-guvenlik-ve-yetkilendirme.md). SaaS çok-kiracılı mimarisinin ürün tarafı için bkz. [10 — SaaS Vizyonu](10-saas-vizyonu.md).

## 6. Transaction Kuralı

Aşağıdaki işlemler **transaction içinde** ele alınmalıdır:

- Tahsilat oluşturma
- Stok hareketi
- Belge oluşturma
- İş tamamlanması
- Finans kaydı

Kısmi başarısızlık durumunda sistem **tutarsız bir durumda bırakılmamalıdır** (örneğin: stok düşüldü ama tahsilat kaydı oluşmadı gibi bir senaryo asla yaşanmamalıdır).

## 7. API Authorization Katmanları

Her endpoint isteği şu sıradan geçmelidir:

```
Authentication → Company Context → Authorization → Resource Policy → Action
```

> ⚠️ **Kritik kural:** Frontend'deki (mobil uygulamadaki) gizli route kontrolü **güvenlik önlemi olarak kabul edilmez.** Her yetkilendirme kararı sunucu tarafında, ilgili `Policy` sınıfı üzerinden verilmelidir.
