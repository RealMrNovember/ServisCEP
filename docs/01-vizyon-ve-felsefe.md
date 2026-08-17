# 01 — Vizyon ve Felsefe

> Kaynak: orijinal spesifikasyon §78–80, §89–91, §94 ve PROJECT STATUS/FINAL PRODUCT PRINCIPLE blokları.

## Ürünün Amacı

ServisCEP'in amacı **"her şeyi yapan dev bir ERP olmak" değildir.**

Amaç: **sahada çalışan teknik işletmenin telefonunu, işletmenin merkezine dönüştürmek.**

Ürün, saha teknik servis işletmelerinin (elektrik, güvenlik sistemleri, bilgisayar/network vb.) günlük operasyon zincirini tek bir mobil uygulamada birleştirir:

```
Müşteri → Talep → İş → Servis → Belge → Tahsilat → Finans → Geçmiş
```

## Ana Kullanıcı Deneyimi

Kullanıcı uygulamayı açtığında aklındaki soru şudur: **"Bugün ne yapacağım?"**

Uygulama bu soruyu doğrudan cevaplamalıdır — ekstra tıklama, menü gezme veya yorumlama gerektirmeden. Örnek ana ekran deneyimi:

```
Bugün 3 işin var.

10:00  ABC Market — Kamera arızası
14:00  Mehmet Kaya — Bilgisayar kurulumu
18:00  XYZ Apartmanı — İnterkom arızası

Bugün tahsil edilmesi beklenen: ₺4.750
```

Bu "günün özeti" yaklaşımı, ürünün tüm ekran tasarımlarının merkezinde olmalıdır.

## Hedef Kullanıcı ve Geliştirme Stratejisi

- **İlk kullanıcı:** Gerçek bir saha teknik servis işletmecisi (proje kaynağında "İbrahim" olarak anılıyor).
- **Birinci hedef:** Bu kullanıcının günlük işlerini tamamen mobil hale getirmek.
- **İkinci hedef:** Gerçek kullanım verileriyle ürünü olgunlaştırmak.
- **Üçüncü hedef:** Ürün–pazar uyumu doğrulandıktan sonra, teknik servis ve saha işletmeleri için genel bir SaaS ürününe dönüştürmek.

Geliştirme stratejisi kasıtlı olarak **"tek gerçek kullanıcı önce, ölçek sonra"** sırasını izler. Önce dar ve derin bir problem tam olarak çözülür, ardından yatay olarak büyütülür.

## Uzun Vadeli Vizyon

> Türkiye'deki küçük ve orta ölçekli saha hizmet işletmelerinin günlük operasyonlarını yönetebileceği modern, mobil-first bir işletme platformu oluşturmak.

Nihai ürün deneyimi, kullanıcı sabah uygulamayı açtığında şunu görmelidir:

```
Günaydın. Bugün 4 işin var.
2 müşteriden toplam ₺7.500 tahsilat bekleniyor.
1 teklif cevap bekliyor.
3 müşterinin bakım zamanı yaklaşıyor.
```

Kullanıcı bir bilgisayara ihtiyaç duymadan müşterilerini, işlerini, servislerini, belgelerini, tahsilatlarını ve gelir-giderini tek elden yönetebilmeli; gün sonunda **"Bugün ne yaptım, ne kazandım, kimden alacağım var ve yarın ne yapacağım?"** sorusunun cevabını tek ekranda görebilmelidir.

## Geliştirme Felsefesi

Kod her zaman şu niteliklere sahip olmalıdır:

- **Basit** — gereksiz soyutlama yok
- **Modüler** — bağımsız test edilebilir ve genişletilebilir parçalar
- **Test edilebilir**
- **Dokümante**
- **Güvenli**
- **Ölçeklenebilir**

> **Kritik kural:** "Şimdilik böyle yapalım, sonra düzeltiriz" yaklaşımı — özellikle **veri modeli** ve **yetkilendirme** gibi kritik alanlarda — kullanılamaz. Bu iki alandaki hatalar sonradan yüksek maliyetle düzeltilir; ilk günden doğru tasarlanmalıdır.

Detaylı geliştirme kuralları için bkz. [11 — Geliştirme Prensipleri](11-gelistirme-prensipleri.md).

## Proje Durumu

| Alan | Değer |
|---|---|
| Proje | ServisCEP |
| Aşama | Planlama |
| MVP | Başlamadı |
| Hedef Platform | Android (Flutter) |
| Backend | Laravel |
| Veritabanı | PostgreSQL |
| Mimari | Offline-First |
| İş Modeli | Tekil işletme → SaaS |
| Öncelik | Yüksek |
| Sıradaki Adım | Mimari + Veritabanı + MVP Implementasyonu |

## Nihai Ürün Prensibi

> Karmaşık bir sistemi kullanıcıya karmaşık hissettirmeden sun.
> Kullanıcının telefonunu, işletmesinin merkezine dönüştür.
