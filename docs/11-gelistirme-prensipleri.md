# 11 — Geliştirme Prensipleri

> Kaynak: orijinal spesifikasyon §70–§72, §81, §93.

Bu doküman, kod yazan herkesin (insan geliştirici veya AI destekli geliştirme ajanı) uyması gereken bağlayıcı kuralları tanımlar.

## Test Stratejisi

**Backend (Laravel):** Unit tests · Feature tests · API tests · Authorization tests

**Mobil (Flutter):** Unit tests · Widget tests · Integration tests

### Test Edilmesi Zorunlu Kritik Senaryolar

- Müşteri oluşturma
- İş oluşturma
- Servis tamamlama
- PDF oluşturma
- Tahsilat
- Offline kayıt
- Sync
- Yetkisiz erişim
- Dosya upload

## Gerçek Hayat Test Senaryosu

Aşağıdaki uçtan uca senaryo, **MVP'nin kabul testi**dir. Bu senaryo eksiksiz çalışmadan MVP tamamlanmış sayılamaz:

1. İnternet kapatılır.
2. Yeni müşteri oluşturulur.
3. Yeni servis oluşturulur.
4. Fotoğraf çekilir.
5. Servis formu hazırlanır.
6. Müşteri imza atar.
7. Tahsilat girilir.
8. İnternet açılır.
9. Sistem otomatik sync olur.
10. Sunucuda bütün kayıtlar görünür.
11. PDF oluşturulur.
12. WhatsApp ile paylaşılır.

## UX Testi

Gerçek kullanıcı, **yardım almadan** aşağıdaki işlemleri yapabilmelidir:

- Müşteri eklemek
- Servis oluşturmak
- Fotoğraf eklemek
- Servisi tamamlamak
- PDF göndermek
- Tahsilat girmek
- Gelir/gider görmek
- Eski müşteriyi bulmak

> **Kabul kriteri:** Kullanıcı bir işlem için geliştiriciye ihtiyaç duyuyorsa, UX yeterince iyi değildir.

## AI Destekli Geliştirme Kuralları

TeknikCEP'te AI destekli bir geliştirme ajanı (Cursor, Claude Code vb.) ile çalışılırken aşağıdaki kurallar bağlayıcıdır:

1. Önce mevcut yapı analiz edilmeli, sonra kod yazılmalıdır.
2. Rastgele/plansız dosya oluşturulmamalıdır.
3. Mevcut mimari bozulmadan geliştirme yapılmalıdır.
4. Veritabanı değişiklikleri **migration** ile yapılmalıdır.
5. API contract'ları değiştirilmeden önce etkisi kontrol edilmelidir.
6. Güvenlik kontrolleri hiçbir gerekçeyle atlanmamalıdır.
7. Test yazılmadan kritik bir modül "tamamlandı" sayılmamalıdır.
8. Mock data, gerçek database akışıyla karıştırılmamalıdır.
9. UI katmanında hardcoded business logic bulunmamalıdır.
10. Şirket izolasyonu (`company_id` scope) hiçbir koşulda bozulmamalıdır.
11. Finansal değerlerde floating-point hesaplama kullanılmamalıdır (bkz. [04 — Finans ve Stok § Para Hesaplama Kuralı](04-finans-ve-stok.md#para-hesaplama-kuralı-kritik--teknik-zorunluluk)).
12. Dosyalar public olarak açılmamalıdır (bkz. [09 — Güvenlik ve Yetkilendirme § Dosya Güvenliği](09-guvenlik-ve-yetkilendirme.md#3-dosya-güvenliği)).
13. Yetkilendirme yalnızca frontend'e bırakılmamalıdır — her karar sunucu tarafında doğrulanmalıdır.
14. Kullanıcıdan gereksiz bilgi istenmemelidir (form tasarımı ilkesiyle uyumlu, bkz. [06 — Teknik Mimari § Form Tasarımı](06-teknik-mimari.md#3-form-tasarımı)).

## Definition of Done (Bitmiş Sayılma Kriteri)

Bir özellik, aşağıdaki **tüm** maddeler karşılanmadan "tamamlandı" sayılamaz:

- [ ] Backend hazır
- [ ] Database migration hazır
- [ ] API hazır
- [ ] Authorization hazır
- [ ] Mobile UI hazır
- [ ] Loading state hazır
- [ ] Empty state hazır
- [ ] Error state hazır
- [ ] Validation hazır
- [ ] Offline davranış belirlenmiş
- [ ] Testler yazılmış
- [ ] Gerçek cihazda test edilmiş
- [ ] Dokümantasyon güncellenmiş

Her `PHASE` (bkz. [ROADMAP.md](../ROADMAP.md)) bu kriterin tamamını karşılamadan bir sonraki faza geçilmemelidir.
