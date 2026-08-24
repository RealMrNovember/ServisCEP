# 10 — SaaS Vizyonu

> Kaynak: orijinal spesifikasyon §53–§55.
>
> Bu doküman **V3 roadmap kapsamındaki** hedef mimariyi tanımlar — MVP'de uygulanmaz, ancak veri modeli ve mimari kararlar en baştan bu vizyonla uyumlu olmalıdır (bkz. [12 — MVP Kapsamı](12-mvp-kapsami.md)).

## Genel Vizyon

İlk kullanıcının uygulaması başarılı olur ve ürün-pazar uyumu doğrulanırsa, ürün genel bir SaaS ürününe dönüştürülebilir.

### Örnek Onboarding Akışı (Self-Servis)

```
TeknikCEP'e Hoş Geldiniz

İşletme türünüz:
☑ Elektrik  ☑ Kamera  ☑ Bilgisayar

Firma bilgilerinizi girin.
Logo yükleyin.
IBAN girin.

Hazırsınız.
```

Bu akış, yeni bir işletmenin dakikalar içinde kendi verisini oluşturup kullanmaya başlayabilmesini hedefler.

## SaaS Tenancy (Çok Kiracılı Mimari)

- Her şirket bir **`Company`** varlığı olarak kabul edilir.
- Kullanıcılar (`Users`) her zaman bir şirkete bağlıdır.
- Tüm veriler `company_id` ile izole edilir.

> Bu tenancy modelinin teknik/güvenlik gereksinimleri için bkz. [07 — API ve Veritabanı § Şirket Bazlı Veri Ayrımı](07-api-ve-veritabani.md#5-şirket-bazlı-veri-ayrımı-multi-tenancy).

## Abonelik Modeli (V3+, MVP Kapsamında Değil)

| Plan | Kapsam |
|---|---|
| **Free** | 1 kullanıcı, 50 müşteri, temel işler, temel belgeler |
| **Pro** | Sınırsız müşteri, sınırsız işler, PDF, Finans, Stok, Raporlar |
| **Business** | Çoklu kullanıcı, yetkilendirme, gelişmiş rapor, API, entegrasyonlar |

> Bu abonelik modeli **ilk MVP'de uygulanmayacaktır.** Amaç, gelecekteki paketleme kararlarını erken belgelemek ve veri modelinin (özellikle kullanım limitleri gerektirecek alanların) bu yapıyı destekleyecek şekilde tasarlanmasını sağlamaktır.
