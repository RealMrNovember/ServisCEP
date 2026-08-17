# 12 — MVP Kapsamı

> Kaynak: orijinal spesifikasyon §56, §88.

## İlk Sürümde Yapılmayacaklar

MVP'yi gereksiz büyütmemek için aşağıdaki başlıklar **ilk sürümde zorunlu değildir** ve bilinçli olarak roadmap'e bırakılmıştır (bkz. [ROADMAP.md](../ROADMAP.md)):

- Komple muhasebe sistemi
- Resmi e-Fatura altyapısı
- Maaş sistemi
- Tam ERP
- Gelişmiş stok
- Gelişmiş CRM
- WhatsApp Business API
- Online ödeme altyapısı
- AI
- Multi-company yönetimi

Bu liste, MVP kapsamının **kasıtlı ve disiplinli** şekilde daraltıldığını belgeler — eksiklik değil, tasarım kararıdır. Bu maddeler için mimari, veri modelinde ileride eklenebilecek şekilde tasarlanmış olsa da (bkz. ilgili katman dokümanları), kod düzeyinde uygulanmamıştır.

## MVP Başarı Kriteri

MVP, aşağıdaki uçtan uca akış **tek bir kullanıcı tarafından, bilgisayara ihtiyaç duymadan** tamamlanabildiğinde başarılı sayılır:

```
Müşteri oluşturabilir
        ↓
Talep alabilir
        ↓
Servis planlayabilir
        ↓
Servis gerçekleştirebilir
        ↓
Fotoğraf ekleyebilir
        ↓
İmza alabilir
        ↓
Servis formu oluşturabilir
        ↓
PDF gönderebilir
        ↓
Tahsilat girebilir
        ↓
Gelir/gider görebilir
```

Bu akış tamamen mobil cihaz üzerinden, ofis/bilgisayar bağımlılığı olmadan yürütülebilmelidir.

## İlgili Kabul Kriterleri

- Offline uçtan uca senaryo: [11 — Geliştirme Prensipleri § Gerçek Hayat Test Senaryosu](11-gelistirme-prensipleri.md#gerçek-hayat-test-senaryosu)
- UX kabul kriteri: [11 — Geliştirme Prensipleri § UX Testi](11-gelistirme-prensipleri.md#ux-testi)
- Her özellik için Definition of Done: [11 — Geliştirme Prensipleri § Definition of Done](11-gelistirme-prensipleri.md#definition-of-done-bitmiş-sayılma-kriteri)
- Geliştirme sırası (Sprint 1-8 / Phase 1-20): [ROADMAP.md](../ROADMAP.md)
