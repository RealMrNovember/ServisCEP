# 09 — Güvenlik ve Yetkilendirme

> Kaynak: orijinal spesifikasyon §37–§41, §69, §73, §76–§77.

## 1. Yetkilendirme (Roller)

**İlk sürüm (MVP):** Sadece `OWNER` rolü desteklenir.

**Gelecek roller (V2+):**

| Rol | Açıklama |
|---|---|
| `OWNER` | Tam yetki, şirket sahibi |
| `ADMIN` | Yönetici, çoğu işlemi yapabilir |
| `TECHNICIAN` | Saha teknisyeni |
| `ACCOUNTING` | Finans/muhasebe erişimi |
| `VIEWER` | Salt okunur erişim |

### Örnek Yetki Matrisi — Teknisyen

| İzin | Teknisyen |
|---|---|
| İşleri görebilir | ✅ |
| Servis formu doldurabilir | ✅ |
| Fotoğraf ekleyebilir | ✅ |
| Finansal raporları görebilir | ❌ |
| Şirket ayarlarını değiştirebilir | ❌ |
| Kullanıcı silebilir | ❌ |

## 2. Güvenlik Kontrol Listesi (Temel)

- HTTPS zorunlu
- Token tabanlı authentication
- Secure storage (mobil tarafta hassas veri)
- API rate limiting
- Server-side authorization (her zaman sunucu tarafında doğrulama)
- Input validation
- SQL injection koruması
- XSS koruması
- CSRF koruması (uygun katmanlarda)
- Dosya upload validation
- MIME validation
- Maksimum dosya boyutu sınırı
- Audit log
- Hassas verilerin güvenli saklanması

## 3. Dosya Güvenliği

Fotoğraf ve belgeler **doğrudan public web klasöründe tutulamaz.**

Dosyalar şu mantıkla saklanmalıdır:

```
private/company/{company_id}/...
```

Dosyaya erişim yalnızca şu üçlü ile sağlanmalıdır:

1. Yetkilendirilmiş API çağrısı
2. Signed URL (süreli, imzalı erişim linki)
3. Permission kontrolü (kullanıcının o `company_id`'ye ve kaynağa erişim yetkisi)

## 4. Backup

**Minimum (MVP):**

- Günlük database backup
- Dosya backup
- Backup retention (saklama süresi politikası)
- Restore testi (yedeğin geri yüklenebilir olduğunun düzenli doğrulanması)

**SaaS aşamasında değerlendirilecekler:**

- Point-in-time recovery
- Disaster recovery
- Çoklu storage (coğrafi/sağlayıcı çeşitlendirmesi)

## 5. Audit Log

Önemli işlemler kayıt altına alınmalıdır.

### Örnek Kayıt

```
Kullanıcı:  İbrahim
Zaman:      20.08.2026 18:42
Servis:     SRV-2026-00142
İşlem:      Servis tamamlandı.
Tutar:      2.350 TL
```

### Audit Log Gerektiren Kritik İşlemler

- Belge oluşturma
- Belge silme
- Tahsilat
- Müşteri değişikliği
- Yetki değişikliği
- Firma ayarı değişikliği

## 6. Logging

**Backend:** Error logs · Request logs · Queue logs · Audit logs

**Mobil:** Crash reporting · Sync errors · Network errors

> Kullanıcıya hiçbir zaman teknik stack trace gösterilmemelidir — hatalar her zaman kullanıcı dostu, aksiyon önerir mesajlara çevrilmelidir.

## Veri Silme Prensibi

Finansal veya önemli iş kayıtları **doğrudan hard delete edilmemelidir.**

- Genel kayıtlarda `deleted_at` (soft delete) kullanılabilir.
- Kritik belgelerde (teklif, proforma, fatura, iş) silme yerine **`İPTAL`** durumu tercih edilmelidir.

Bu ilke, hem audit log bütünlüğünü hem de finansal kayıtların geriye dönük izlenebilirliğini korur.

## KVKK ve Veri Gizliliği

Sistem, aşağıdaki gibi kişisel veriler saklayacaktır:

Ad · Soyad · Telefon · Adres · E-posta

Bu nedenle aşağıdakiler tasarlanmalı ve belgelenmelidir:

- Açık ve anlaşılır gizlilik politikası
- Veri işleme süreçleri
- Yetki kontrolü
- Veri silme talepleri (KVKK md. 7/11 kapsamındaki "unutulma hakkı" başvuru süreci)
- Veri güvenliği
- Backup güvenliği

> Bu doküman bir KVKK uyum raporu yerine geçmez; ürün büyüdükçe (özellikle SaaS aşamasında çok sayıda gerçek kişi verisi işlendiğinde) resmi bir KVKK uyum değerlendirmesi ayrıca yapılmalıdır.

## Hukuki Sınır (Konumlandırma)

ServisCEP **"muhasebe programı"** olarak konumlandırılmak zorunda değildir.

**MVP konumlandırması:** *İşletme ve teknik servis yönetim platformu.*

- Resmi fatura / e-Fatura / e-Arşiv gibi özellikler gerektiğinde, ilgili mevzuat ve yetkili entegratör gereksinimleri **ayrıca** değerlendirilmelidir (bkz. [03 § Fatura Yaklaşımı](03-servis-ve-belge-yonetimi.md#7-fatura-yaklaşımı-mvp-kapsamı)).
- Sistem, oluşturduğu servis formu, teklif veya proformayı **otomatik olarak "resmi fatura" olarak tanımlamamalıdır** — bu hem hukuki hem de kullanıcı güveni açısından kritik bir sınırdır.
- Dijital imzanın resmi elektronik imza yerine geçmediği konusunda da aynı netlik korunmalıdır (bkz. [03 § Dijital İmza](03-servis-ve-belge-yonetimi.md#2-dijital-imza)).
