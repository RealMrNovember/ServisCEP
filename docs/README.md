# ServisCEP — Dokümantasyon İndeksi

Bu dizin, ServisCEP projesinin ürün, mimari ve geliştirme dokümantasyonunu barındırır. Dokümanlar, orijinal proje spesifikasyonu (`99-orijinal-spesifikasyon.md`) temel alınarak katman ve iş alanına (sektör) göre ayrılmıştır.

## İçindekiler

| # | Doküman | Kapsam |
|---|---------|--------|
| 01 | [Vizyon ve Felsefe](01-vizyon-ve-felsefe.md) | Ürün vizyonu, hedef kullanıcı, geliştirme felsefesi, proje durumu |
| 02 | [İş Alanı ve Veri Modeli](02-is-alani-ve-veri-modeli.md) | Müşteri, iş/servis, talep modülleri — temel domain kavramları |
| 03 | [Servis ve Belge Yönetimi](03-servis-ve-belge-yonetimi.md) | Servis formu, dijital imza, fotoğraf, teklif, proforma, fatura, belge merkezi, PDF motoru |
| 04 | [Finans ve Stok](04-finans-ve-stok.md) | Gelir/gider, tahsilat, finans dashboard, stok, para birimi ve KDV kuralları |
| 05 | [Takvim, Bildirim ve İletişim](05-takvim-bildirim-iletisim.md) | Randevu takvimi, harita, hatırlatmalar, bildirimler, WhatsApp paylaşımı |
| 06 | [Teknik Mimari](06-teknik-mimari.md) | Mobil UX prensipleri, navigasyon, arama/filtreleme, teknoloji yığını |
| 07 | [API ve Veritabanı](07-api-ve-veritabani.md) | API tasarım prensipleri, response standardı, veritabanı ana modeli, çok kiracılı izolasyon |
| 08 | [Offline-First ve Senkronizasyon](08-offline-first-ve-senkronizasyon.md) | Yerel veritabanı, sync queue, conflict yönetimi |
| 09 | [Güvenlik ve Yetkilendirme](09-guvenlik-ve-yetkilendirme.md) | Roller, güvenlik kontrolleri, dosya güvenliği, audit log, KVKK, hukuki sınırlar |
| 10 | [SaaS Vizyonu](10-saas-vizyonu.md) | Çok kiracılı mimari, abonelik modeli, self-servis onboarding |
| 11 | [Geliştirme Prensipleri](11-gelistirme-prensipleri.md) | Test stratejisi, AI destekli geliştirme kuralları, Definition of Done |
| 12 | [MVP Kapsamı](12-mvp-kapsami.md) | MVP'de olmayacaklar, başarı kriterleri |
| 13 | [Web Arayüzü ve Showroom](13-web-arayuzu-ve-showroom.md) | Showroom (tanıtım sitesi), web panel, mobil showcase entegrasyonu |
| 14 | [Marka Kimliği](14-marka-kimligi.md) | Logo, renk paleti, ikon varlıkları ve kullanım kuralları |
| 99 | [Orijinal Spesifikasyon (Arşiv)](99-orijinal-spesifikasyon.md) | `idea.md`'nin bölünmeden önceki tam hali — referans amaçlı arşiv |

## İlgili Dosyalar

- Proje genel bakışı için köke bakın: [README.md](../README.md)
- Geliştirme yol haritası için: [ROADMAP.md](../ROADMAP.md)

## Doküman Yapısı Kuralı

Her doküman, orijinal spesifikasyondaki ilgili bölüm numaralarına atıfta bulunur (örn. *"bkz. orijinal §14"*) böylece iki kaynak arasında izlenebilirlik korunur. Ürün geliştikçe bu dokümanlar güncel tutulmalı, orijinal arşiv dosyası ise değiştirilmeden referans olarak kalmalıdır.
