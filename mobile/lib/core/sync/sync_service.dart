import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
// ValueNotifier için; widget katmanı çekilmiyor ki senkron motoru
// Flutter arayüzünden bağımsız kalsın.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../services/media_storage.dart';
import '../network/api_client.dart';
import '../network/sync_api_client.dart';
import '../network/token_store.dart';
import '../providers/core_providers.dart';

/// Mobil senkron motoru — bkz. ROADMAP.md § B10 mobil yarısı.
///
/// Akış: önce outbox'taki bekleyen yazmalar sunucuya gönderilir (push),
/// sonra sunucu listeleri çekilip yerel taze olmayan kayıtlar güncellenir
/// (pull). Bir kaydın PENDING bir outbox girdisi varsa pull o kaydı EZMEZ —
/// "telefon offline yazdı, ofis de yazdı" senaryosunda yerel taslağın
/// üzerine sessizce yazılmaması bu motorun asıl amacı.
///
/// Kapsam (dikey dilim 2 + medya, 2026-08-24):
/// - Push + pull: Customer, Job, ServiceRequest, Quote, Proforma
/// - Push-only: Payment, IncomeEntry, ExpenseEntry (create-only kayıtlar —
///   sunucuda düzenlenmezler, çakışma riski yok; pull edilmemeleri bilinçli,
///   web panelde girilen finans kayıtları mobilde görünmez)
/// - Push-only (medya): JobNote, JobPhoto, JobSignature — dosyalar payload'da
///   değil, gönderim anında diskten multipart okunur; dosya silinmişse satır
///   FAILED olur (sessizce atlanmaz). Panelde eklenen medya mobile İNMEZ
///   (medya telefonda üretilir, panel görüntüleme yeridir).
/// - Pull-only: CustomerLedgerEntries — cari hesabın tek doğruluk kaynağı
///   SUNUCUDUR. Telefon iyimser yerel kayıt tutar, pull sırasında sunucunun
///   kaydıyla değiştirilir (bkz. _pullLedgerEntries). Böylece iki tarafın
///   bağımsız hesaplayıp bakiyelerin sessizce ayrışması riski kalkar.
class SyncService {
  SyncService(this._db, this._api, this._tokenStore);

  final AppDatabase _db;
  final SyncApiClient _api;
  final TokenStore _tokenStore;

  /// Şu anda bir senkron turu çalışıyor mu.
  ///
  /// Arayüzün "Eşitleniyor" diyebilmesi için GERÇEK bir sinyal gerekiyor.
  /// Kuyrukta kayıt olması turun çalıştığı anlamına gelmez: cihazın
  /// interneti varken bile sunucuya hiç ulaşılamayabiliyor. Bu ayrımı
  /// yapmadan yazılan her "gönderiliyor" metni, kullanıcıya söylenmiş bir
  /// yalan oluyor.
  final ValueNotifier<bool> calisiyor = ValueNotifier<bool>(false);

  /// Halihazırda çalışan tur — aynı anda ikinci bir tur BAŞLATILMAZ.
  ///
  /// `calisiyor` yalnızca YAZILIYOR, hiç OKUNMUYORDU. Uygulama öne gelirken
  /// resume + bağlantı + periyodik tetikleyiciler aynı saniyeye denk
  /// geldiğinde (tipik senaryo) 2-3 tur aynı PENDING listesini okuyup aynı
  /// CREATE'i iki kez POST ediyordu. İkinci deneme hata alınca satır çoktan
  /// silinmiş oluyor — güncelleme no-op — ama `_setEntitySyncStatus`
  /// varlığın kendisini FAILED'e boyuyordu: sunucuya BAŞARIYLA gitmiş bir
  /// kayıt kullanıcıya "gönderilemedi" olarak görünüyordu.
  Future<bool>? _calisanTur;

  /// Bir senkron turu çalıştırır ve BAŞARIYI döndürür.
  ///
  /// Dönüş değeri kritik: hatalar burada bilinçli olarak yutuluyor
  /// (`unawaited` çağrıldığı için dışarı sızmamalı), ama yutulan hata
  /// "başarılı" sayılınca "son senkron" zamanı sunucuya hiç ulaşılamadığı
  /// hâlde güncelleniyordu. Ekran da bunu "az önce eşitlendi" diye
  /// gösteriyordu — kullanıcıya söylenen düpedüz yanlış bir bilgi.
  ///
  /// Zaten süren bir tur varsa YENİSİ AÇILMAZ; çağıran o turun sonucunu alır.
  Future<bool> runOnce(String companyId) {
    final mevcut = _calisanTur;
    if (mevcut != null) return mevcut;

    final tur = _runOnceKorumali(companyId);
    _calisanTur = tur;
    return tur.whenComplete(() => _calisanTur = null);
  }

  Future<bool> _runOnceKorumali(String companyId) async {
    if (await _tokenStore.read() == null) return false;

    calisiyor.value = true;
    try {
      return await _runOnce(companyId);
    } finally {
      calisiyor.value = false;
    }
  }

  Future<bool> _runOnce(String companyId) async {
    try {
      // `_drainOutbox()` BİLEREK try'ın İÇİNDE: eskiden dışarıdaydı ve
      // içinden sızan her beklenmedik hata (bozuk payload'ın jsonDecode'u,
      // bilinmeyen operasyon türünün StateError'ı, bir DB hatası)
      // `_runOnce`'tan çıkıp `runOnce`'ın finally'sini geçiyor, `unawaited`
      // çağrısı yüzünden de tamamen yutuluyordu. Sonuç: tek bir bozuk
      // outbox satırı, HER senkron turunu — push'u da pull'u da — sonsuza
      // kadar öldürüyordu ve hiçbir yerde tek satır iz kalmıyordu.
      await _drainOutbox();
      // Her adımdan önce oturum yeniden kontrol edilir.
      //
      // Sebep: bir senkron turu sürerken kullanıcı çıkış yapabiliyor.
      // Yalnızca başlangıçta bakmak yetmiyordu; token silindikten sonra
      // kalan adımlar yetkisiz gidip 401 üretiyor, admin panelindeki
      // günlük de bunları gerçek bir arıza gibi gösteriyordu.
      for (final pull in <Future<void> Function()>[
        () => _pullCompany(companyId),
        () => _pullCustomers(companyId),
        () => _pullJobs(companyId),
        () => _pullServiceRequests(companyId),
        () => _pullQuotes(companyId),
        () => _pullProformas(companyId),
        () => _pullLedgerEntries(companyId),
      ]) {
        if (await _tokenStore.read() == null) return false;
        await pull();
      }
    } on ApiException {
      // Ağ hatası, süresi dolmuş abonelik (402) veya geçici sunucu hatası —
      // pull bir sonraki tetiklemede yeniden dener; `runOnce` unawaited
      // çağrıldığı için buradan exception SIZMAMALI (bkz. SyncTrigger).
      return false;
    } on Object catch (e, s) {
      // Son savunma hattı: buraya düşen her şey bir yazılım hatasıdır ve
      // sessizce yutulursa senkron motoru kalıcı olarak ölür. Tur başarısız
      // sayılır (ekran "eşitlendi" DEMEZ) ama bir sonraki tetikleme yeniden
      // dener; bozuk satır `_drainOutbox` içinde kalıcı FAILED'e alındığı
      // için kuyruk da kilitlenmez.
      debugPrint('Senkron turu beklenmedik hatayla düştü: $e\n$s');
      return false;
    }

    return true;
  }

  /// Yalnızca outbox'ı gönderir (pull YOK) — arka plan görevi için.
  ///
  /// Arka planda kullanıcıya gösterilecek bir ekran olmadığı için sunucudan
  /// veri çekmenin anlamı yok; önemli olan kullanıcının çevrimdışı yazdığı
  /// kaydın sunucuya ulaşması. Hata dışarı sızmaz: arka plan görevinden
  /// fırlayan hata, işletim sisteminin görevi tekrar tekrar denemesine yol
  /// açar (bkz. background_sync.dart).
  Future<void> drainOutboxOnly() async {
    if (await _tokenStore.read() == null) return;
    try {
      await _drainOutbox();
    } on Object catch (e) {
      debugPrint('Arka plan outbox gönderimi düştü: $e');
    }
  }

  Future<void> _drainOutbox() async {
    final pending =
        await (_db.select(_db.syncOperations)
              ..where((o) => o.status.equals('PENDING'))
              ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
            .get();

    for (final op in pending) {
      try {
        // `jsonDecode` BİLEREK try'ın İÇİNDE: bozuk bir payload eskiden
        // döngünün dışına sızıp bütün turu (pull dahil) öldürüyordu.
        final payload = jsonDecode(op.payload) as Map<String, dynamic>;
        switch ((op.entityType, op.operation)) {
          case ('customer', 'CREATE'):
            final result = await _api.createCustomer(payload);
            await _markSynced('customer', result);
          case ('customer', 'UPDATE'):
            final result = await _api.updateCustomer(op.entityId, {
              ...payload,
              'base_version': op.baseVersion,
            });
            await _markSynced('customer', result);
          case ('customer', 'DELETE'):
            await _api.deleteCustomer(op.entityId);
          case ('job', 'CREATE'):
            final result = await _api.createJob(payload);
            await _markSynced('job', result);
          case ('job', 'UPDATE'):
            final result = await _api.updateJob(op.entityId, {
              ...payload,
              'base_version': op.baseVersion,
            });
            await _markSynced('job', result);
          case ('service_request', 'CREATE'):
            final result = await _api.createServiceRequest(payload);
            await _markSynced('service_request', result);
          case ('service_request', 'UPDATE'):
            final result = await _api.updateServiceRequest(op.entityId, {
              ...payload,
              'base_version': op.baseVersion,
            });
            await _markSynced('service_request', result);
          case ('service_request', 'CONVERT'):
            // Backend işi bizim job_id'mizle kendisi oluşturur ve işin son
            // hâlini döndürür — yerel iş (kod/başlık sunucu türetmesiyle)
            // hizalanır. Talebin yeni version'ı yanıtında yok; bir sonraki
            // pull düzeltir, şimdilik SYNCED işaretlemek yeterli.
            final job = await _api.convertServiceRequest(
              op.entityId,
              payload['job_id'] as String,
            );
            await _applyConvertedJob(job);
            await (_db.update(
              _db.serviceRequests,
            )..where((r) => r.id.equals(op.entityId))).write(
              const ServiceRequestsCompanion(syncStatus: Value('SYNCED')),
            );
          case ('quote', 'CREATE'):
            final result = await _api.createQuote(payload);
            await _markSynced('quote', result);
          case ('quote', 'UPDATE'):
            final result = await _api.updateQuote(op.entityId, {
              ...payload,
              'base_version': op.baseVersion,
            });
            await _markSynced('quote', result);
          case ('proforma', 'CREATE'):
            final result = await _api.createProforma(payload);
            await _markSynced('proforma', result);
          case ('payment', 'CREATE'):
            // customer_id URL yolu içindir, istek gövdesine girmez.
            final body = Map<String, dynamic>.from(payload)
              ..remove('customer_id');
            await _api.createPayment(payload['customer_id'] as String, body);
          case ('income_entry', 'CREATE'):
            await _api.createIncomeEntry(payload);
          case ('expense_entry', 'CREATE'):
            await _api.createExpenseEntry(payload);
          case ('customer', 'TAX_CERTIFICATE'):
            if (!File(payload['file_path'] as String).existsSync()) {
              await _markFailed(
                op,
                ApiException(422, 'Vergi levhası dosyası artık cihazda yok.'),
                kalici: true,
              );
              continue;
            }
            await _api.uploadTaxCertificate(
              op.entityId,
              payload['file_path'] as String,
            );
            await (_db.update(
              _db.customers,
            )..where((c) => c.id.equals(op.entityId))).write(
              const CustomersCompanion(hasTaxCertificate: Value(true)),
            );
          case ('company', 'UPDATE'):
            await _api.updateCompany(payload);
          case ('company', 'LOGO'):
            final yol = await _guncelLogoYolu(op);
            if (yol == null) {
              await _api.deleteCompanyLogo();
            } else {
              await _api.uploadCompanyLogo(yol);
            }
          case ('customer', 'LOGO'):
            final yol = await _guncelLogoYolu(op);
            if (yol == null) {
              await _api.deleteCustomerLogo(op.entityId);
            } else {
              await _api.uploadCustomerLogo(op.entityId, yol);
            }
          case ('job_note', 'CREATE'):
            await _api.createJobNote(payload['job_id'] as String, {
              'id': payload['id'],
              'note': payload['note'],
            });
          case ('job_photo', 'CREATE'):
            if (!File(payload['file_path'] as String).existsSync()) {
              await _markFailed(
                op,
                ApiException(422, 'Fotoğraf dosyası artık cihazda yok.'),
                kalici: true,
              );
              continue;
            }
            await _api.createJobPhoto(
              payload['job_id'] as String,
              id: payload['id'] as String,
              category: payload['category'] as String,
              filePath: payload['file_path'] as String,
            );
          case ('job_signature', 'CREATE'):
            if (!File(payload['file_path'] as String).existsSync()) {
              await _markFailed(
                op,
                ApiException(422, 'İmza dosyası artık cihazda yok.'),
                kalici: true,
              );
              continue;
            }
            await _api.createJobSignature(
              payload['job_id'] as String,
              id: payload['id'] as String,
              signerName: payload['signer_name'] as String,
              filePath: payload['file_path'] as String,
            );
          default:
            throw StateError(
              'Bilinmeyen sync operasyonu: ${op.entityType}/${op.operation}',
            );
        }
        await _db.delete(_db.syncOperations).delete(op);
      } on ApiConflictException catch (e) {
        await _markConflicted(op, e);
      } on ApiException catch (e) {
        if (e.statusCode == null ||
            e.statusCode == 402 ||
            e.statusCode == 401) {
          // Ağ hatası, abonelik süresi dolmuş (402) veya kimlik geçersiz
          // (401) — kuyruk PENDING kalır: veri kaybolmaz, bağlantı/yenileme
          // /yeniden giriş sonrası akar. 402'de satırları FAILED işaretlemek
          // yanlış olurdu; sorun veride değil, abonelikte (bkz. backend
          // EnsureSubscriptionIsActive).
          //
          // 401 EKLENDİ: token geçersizleştiğinde tüm kuyruk kalıcı FAILED
          // oluyordu ve kullanıcı yeniden giriş yapsa BİLE o kayıtlar bir
          // daha asla gönderilmiyordu — çevrimdışı yazılmış işlerin sessizce
          // telefonda hapsolmasının en sık sebebi buydu.
          return;
        }
        await _markFailed(op, e);
      } on Object catch (e) {
        // Bozuk payload, bilinmeyen operasyon türü, diskten kaybolmuş medya:
        // bu satır hiçbir denemede gönderilemez. Tüm kuyruğu kilitlemesin
        // diye KALICI olarak FAILED'e alınır ve döngü diğer satırlarla
        // devam eder.
        await _markFailed(
          op,
          ApiException(null, 'Gönderilemeyen kayıt: $e'),
          kalici: true,
        );
      }
    }
  }

  /// Gönderilecek logonun O ANKİ yolu.
  ///
  /// Kuyruk satırındaki `file_path` KULLANILMIYOR. Sebebi bir kilitlenme:
  /// [MediaStorage.writeLogo] aynı sahibin eski dosyalarını siliyor, yani
  /// logo ikinci kez yazıldığında (kullanıcı değiştirdiğinde ya da pull
  /// eksik dosyayı sunucudan geri indirdiğinde) ilk satırın işaret ettiği
  /// dosya yok oluyordu. Satır o andan itibaren KALICI hataya alınıyor ve
  /// yeniden denemek de dahil hiçbir şey onu kurtaramıyordu — kullanıcı
  /// "Logo dosyası artık cihazda yok" diyen, asla temizlenmeyen bir
  /// kayıtla kalıyordu.
  ///
  /// Doğru davranış zaten buydu: gönderilmesi gereken, kuyruğa girildiği
  /// andaki dosya değil, kullanıcının ŞU ANKİ logosu. Kayıt silinmişse
  /// null döner ve sunucudaki logo silinir.
  Future<String?> _guncelLogoYolu(SyncOperation op) async {
    final yol = switch (op.entityType) {
      'company' =>
        (await (_db.select(
          _db.companies,
        )..where((c) => c.id.equals(op.entityId))).getSingleOrNull())?.logoPath,
      _ =>
        (await (_db.select(
          _db.customers,
        )..where((c) => c.id.equals(op.entityId))).getSingleOrNull())?.logoPath,
    };

    if (yol == null || yol.isEmpty) return null;

    // Kayıtta yol var ama dosya gerçekten yoksa: silme olarak gönderilir.
    // Kuyruğu sonsuza dek tıkamaktansa sunucuyu cihazla hizalamak doğru.
    return File(yol).existsSync() ? yol : null;
  }

  /// Convert yanıtındaki işin sunucu hâlini yerel kayda uygular — kod
  /// (sunucu 'J-...' üretir, yerel 'SRV-...' idi) ve başlık/açıklama
  /// türetmesi sunucuyla hizalanır.
  Future<void> _applyConvertedJob(Map<String, dynamic> job) {
    return (_db.update(
      _db.jobs,
    )..where((j) => j.id.equals(job['id'] as String))).write(
      JobsCompanion(
        code: Value(job['code'] as String),
        title: Value(job['title'] as String),
        description: Value(job['description'] as String?),
        version: Value((job['version'] as num?)?.toInt() ?? 1),
        syncStatus: const Value('SYNCED'),
      ),
    );
  }

  Future<void> _markSynced(String entityType, SyncEntityResult result) async {
    final version = Value(result.version);
    const synced = Value('SYNCED');
    switch (entityType) {
      case 'customer':
        await (_db.update(_db.customers)..where((c) => c.id.equals(result.id)))
            .write(CustomersCompanion(version: version, syncStatus: synced));
      case 'job':
        await (_db.update(_db.jobs)..where((j) => j.id.equals(result.id)))
            .write(JobsCompanion(version: version, syncStatus: synced));
      case 'service_request':
        await (_db.update(
          _db.serviceRequests,
        )..where((r) => r.id.equals(result.id))).write(
          ServiceRequestsCompanion(version: version, syncStatus: synced),
        );
      case 'quote':
        await (_db.update(_db.quotes)..where((q) => q.id.equals(result.id)))
            .write(QuotesCompanion(version: version, syncStatus: synced));
      case 'proforma':
        await (_db.update(_db.proformas)..where((p) => p.id.equals(result.id)))
            .write(ProformasCompanion(version: version, syncStatus: synced));
      // payment / income_entry / expense_entry: yerel tabloda syncStatus
      // kolonu yok (create-only) — outbox satırının silinmesi yeterli.
    }
  }

  Future<void> _setEntitySyncStatus(SyncOperation op, String status) async {
    final value = Value(status);
    switch (op.entityType) {
      case 'customer':
        await (_db.update(_db.customers)
              ..where((c) => c.id.equals(op.entityId)))
            .write(CustomersCompanion(syncStatus: value));
      case 'job':
        await (_db.update(_db.jobs)..where((j) => j.id.equals(op.entityId)))
            .write(JobsCompanion(syncStatus: value));
      case 'service_request':
        await (_db.update(_db.serviceRequests)
              ..where((r) => r.id.equals(op.entityId)))
            .write(ServiceRequestsCompanion(syncStatus: value));
      case 'quote':
        await (_db.update(_db.quotes)..where((q) => q.id.equals(op.entityId)))
            .write(QuotesCompanion(syncStatus: value));
      case 'proforma':
        await (_db.update(_db.proformas)
              ..where((p) => p.id.equals(op.entityId)))
            .write(ProformasCompanion(syncStatus: value));
    }
  }

  Future<void> _markConflicted(SyncOperation op, ApiConflictException e) async {
    await (_db.update(
      _db.syncOperations,
    )..where((o) => o.id.equals(op.id))).write(
      SyncOperationsCompanion(
        status: const Value('CONFLICT'),
        lastError: Value(jsonEncode(e.serverSnapshot)),
      ),
    );
    await _setEntitySyncStatus(op, 'CONFLICT');
  }

  /// Bir satır kaç başarısız denemeden sonra KALICI olarak FAILED sayılır.
  ///
  /// Denemeler arası bekleme ayrı bir zamanlayıcıyla değil, senkron turunun
  /// kendi ritmiyle oluşur (bağlantı değişimi / öne gelme / 3 dakikalık
  /// periyot) — bu yüzden ayrı bir "sonraki deneme zamanı" kolonuna ve şema
  /// göçüne gerek yok.
  static const _maxDeneme = 5;

  /// Başarısız gönderim.
  ///
  /// KRİTİK DAVRANIŞ DEĞİŞİKLİĞİ: geçici hatalarda satır artık PENDING
  /// KALIR ve bir sonraki turda yeniden denenir.
  ///
  /// Eskiden ilk hatada FAILED'e alınıyordu; `_drainOutbox` ise yalnızca
  /// PENDING satırları okuduğu için o kayıt bir daha ASLA gönderilmiyordu.
  /// Hiçbir kod FAILED'i tekrar PENDING'e çevirmiyor, arayüzde "yeniden
  /// dene" düğmesi de bulunmuyordu. Yani tek bir geçici 500 ya da anlık
  /// sunucu hatası, kullanıcının çevrimdışı yazdığı kaydı sonsuza kadar
  /// telefonda hapsediyordu. `attemptCount` artırılıyordu ama hiçbir yerde
  /// okunmadığı için retry/backoff mantığı fiilen hiç yazılmamıştı.
  Future<void> _markFailed(
    SyncOperation op,
    ApiException e, {
    bool kalici = false,
  }) async {
    final deneme = op.attemptCount + 1;
    final bitti = kalici || deneme >= _maxDeneme;
    final durum = bitti ? 'FAILED' : 'PENDING';

    await (_db.update(
      _db.syncOperations,
    )..where((o) => o.id.equals(op.id))).write(
      SyncOperationsCompanion(
        status: Value(durum),
        lastError: Value(e.message),
        attemptCount: Value(deneme),
      ),
    );
    await _setEntitySyncStatus(op, durum);
  }

  /// Kalıcı FAILED satırları yeniden kuyruğa alır (kullanıcı eylemi).
  ///
  /// Deneme sayacı sıfırlanır: kullanıcı "yeniden dene" dediğinde kayıt
  /// tam bir tur hakkı daha kazanır. Gönderilen satır sayısını döndürür.
  Future<int> retryFailed() async {
    final failed = await (_db.select(
      _db.syncOperations,
    )..where((o) => o.status.equals('FAILED'))).get();
    if (failed.isEmpty) return 0;

    await (_db.update(
      _db.syncOperations,
    )..where((o) => o.status.equals('FAILED'))).write(
      const SyncOperationsCompanion(
        status: Value('PENDING'),
        attemptCount: Value(0),
      ),
    );
    for (final op in failed) {
      await _setEntitySyncStatus(op, 'PENDING');
    }
    return failed.length;
  }

  Future<bool> _hasPendingOutboxFor(String entityId) async {
    final row =
        await (_db.select(_db.syncOperations)..where(
              (o) => o.entityId.equals(entityId) & o.status.equals('PENDING'),
            ))
            .getSingleOrNull();
    return row != null;
  }

  /// Şirket antedi ve logosu.
  ///
  /// Sürüm tabanlı çakışma kontrolü yok (bkz. CompanyRepository) — bu kayıt
  /// yalnızca işletme sahibi tarafından seyrek düzenlenir. Bekleyen bir
  /// yerel değişiklik varsa sunucudakine dokunulmaz, aksi halde kullanıcının
  /// az önce yazdığı ünvan geri alınmış olurdu.
  Future<void> _pullCompany(String companyId) async {
    if (await _hasPendingOutboxFor(companyId)) return;

    final remote = await _api.showCompany();
    if (remote == null) return;

    final local = await (_db.select(
      _db.companies,
    )..where((c) => c.id.equals(companyId))).getSingleOrNull();

    await (_db.update(
      _db.companies,
    )..where((c) => c.id.equals(companyId))).write(
      CompaniesCompanion(
        name: Value(remote['name'] as String? ?? local?.name ?? ''),
        businessTypes: Value(
          remote['business_types'] as String? ?? local?.businessTypes ?? '',
        ),
        iban: Value(remote['iban'] as String?),
        address: Value(remote['address'] as String?),
        phone: Value(remote['phone'] as String?),
        email: Value(remote['email'] as String?),
        taxInfo: Value(remote['tax_info'] as String?),
        introText: Value(remote['intro_text'] as String?),
        paymentTerms: Value(remote['payment_terms'] as String?),
        deliveryTime: Value(remote['delivery_time'] as String?),
        warrantyTerms: Value(remote['warranty_terms'] as String?),
        hasLogo: Value(remote['has_logo'] as bool? ?? false),
      ),
    );

    await _syncCompanyLogoFile(
      companyId: companyId,
      hasRemoteLogo: remote['has_logo'] as bool? ?? false,
      localPath: local?.logoPath,
    );
  }

  /// Logonun ikili içeriğini yerelde tutar. PDF üretimi çevrimdışı da
  /// çalışmak zorunda olduğu için logo her cihazda dosya olarak bulunmalı.
  Future<void> _syncCompanyLogoFile({
    required String companyId,
    required bool hasRemoteLogo,
    required String? localPath,
  }) async {
    if (!hasRemoteLogo) {
      if (localPath != null) {
        await MediaStorage.deleteIfExists(localPath);
        await (_db.update(_db.companies)..where((c) => c.id.equals(companyId)))
            .write(const CompaniesCompanion(logoPath: Value(null)));
      }
      return;
    }

    if (localPath != null && File(localPath).existsSync()) return;

    final bytes = await _api.downloadCompanyLogo();
    if (bytes == null || bytes.isEmpty) return;

    final path = await MediaStorage.writeLogo(
      bucket: 'company_logos',
      ownerId: companyId,
      bytes: Uint8List.fromList(bytes),
      stamp: DateTime.now().millisecondsSinceEpoch,
    );
    await (_db.update(_db.companies)..where((c) => c.id.equals(companyId)))
        .write(CompaniesCompanion(logoPath: Value(path)));
  }

  Future<void> _pullCustomers(String companyId) async {
    final remoteRecords = await _api.listCustomers();
    for (final remote in remoteRecords) {
      if (await _hasPendingOutboxFor(remote.id)) continue;

      final local = await (_db.select(
        _db.customers,
      )..where((c) => c.id.equals(remote.id))).getSingleOrNull();
      if (local != null && local.version >= remote.version) continue;

      final r = remote.raw;
      final companion = CustomersCompanion(
        id: Value(remote.id),
        companyId: Value(companyId),
        code: Value(r['code'] as String),
        contactName: Value(r['contact_name'] as String?),
        companyName: Value(r['company_name'] as String?),
        iban: Value(r['iban'] as String?),
        type: Value(r['type'] as String),
        phone: Value(r['phone'] as String?),
        email: Value(r['email'] as String?),
        address: Value(r['address'] as String?),
        il: Value(r['il'] as String?),
        ilce: Value(r['ilce'] as String?),
        taxInfo: Value(r['tax_info'] as String?),
        notes: Value(r['notes'] as String?),
        tags: Value(r['tags'] as String?),
        hasTaxCertificate: Value(r['has_tax_certificate'] as bool? ?? false),
        hasLogo: Value(r['has_logo'] as bool? ?? false),
        version: Value(remote.version),
        syncStatus: const Value('SYNCED'),
      );
      await _db.into(_db.customers).insertOnConflictUpdate(companion);
    }

    await _pullTrashedCustomers();
  }

  /// Tombstone senkronu — ofiste (web panelde) silinen müşteri telefonda
  /// da silinmiş görünmeli. Backend silinen müşteriyi 3 gün çöp kutusunda
  /// tutar; bu pencerede burada yakalanır ve yerelde soft-delete edilir.
  ///
  /// PENDING outbox girdisi olan kayıt ATLANIR: telefon aynı müşteriyi
  /// offline düzenlediyse, kullanıcının bekleyen yazması sessizce
  /// silinmez — önce push edilir, sonuç (409/başarı) ona göre işlenir.
  Future<void> _pullTrashedCustomers() async {
    final trashed = await _api.listTrashedCustomers();
    for (final remote in trashed) {
      if (await _hasPendingOutboxFor(remote.id)) continue;

      final local = await (_db.select(
        _db.customers,
      )..where((c) => c.id.equals(remote.id))).getSingleOrNull();
      if (local == null || local.deletedAt != null) continue;

      await (_db.update(
        _db.customers,
      )..where((c) => c.id.equals(remote.id))).write(
        CustomersCompanion(
          deletedAt: Value(DateTime.now()),
          syncStatus: const Value('SYNCED'),
        ),
      );
    }
  }

  Future<void> _pullJobs(String companyId) async {
    final remoteRecords = await _api.listJobs();
    for (final remote in remoteRecords) {
      if (await _hasPendingOutboxFor(remote.id)) continue;

      final local = await (_db.select(
        _db.jobs,
      )..where((j) => j.id.equals(remote.id))).getSingleOrNull();
      if (local != null && local.version >= remote.version) continue;

      final r = remote.raw;
      final companion = JobsCompanion(
        id: Value(remote.id),
        companyId: Value(companyId),
        code: Value(r['code'] as String),
        customerId: Value(r['customer_id'] as String),
        jobTypeId: Value(r['job_type_id'] as String?),
        title: Value(r['title'] as String),
        description: Value(r['description'] as String?),
        address: Value(r['address'] as String?),
        appointmentDate: Value(
          r['appointment_date'] == null
              ? null
              : DateTime.parse(r['appointment_date'] as String),
        ),
        startTime: Value(r['start_time'] as String?),
        endTime: Value(r['end_time'] as String?),
        priority: Value(r['priority'] as String),
        status: Value(r['status'] as String),
        technicianUserId: Value(r['technician_user_id'] as String?),
        estimatedPriceMinor: Value(
          (r['estimated_price_minor'] as num?)?.toInt(),
        ),
        actualPriceMinor: Value((r['actual_price_minor'] as num?)?.toInt()),
        notes: Value(r['notes'] as String?),
        version: Value(remote.version),
        syncStatus: const Value('SYNCED'),
      );
      await _db.into(_db.jobs).insertOnConflictUpdate(companion);
    }
  }

  Future<void> _pullServiceRequests(String companyId) async {
    final remoteRecords = await _api.listServiceRequests();
    for (final remote in remoteRecords) {
      if (await _hasPendingOutboxFor(remote.id)) continue;

      final local = await (_db.select(
        _db.serviceRequests,
      )..where((r) => r.id.equals(remote.id))).getSingleOrNull();
      if (local != null && local.version >= remote.version) continue;

      final r = remote.raw;
      final companion = ServiceRequestsCompanion(
        id: Value(remote.id),
        companyId: Value(companyId),
        code: Value(r['code'] as String),
        customerId: Value(r['customer_id'] as String),
        description: Value(r['description'] as String),
        priority: Value(r['priority'] as String),
        address: Value(r['address'] as String?),
        status: Value(r['status'] as String),
        convertedJobId: Value(r['converted_job_id'] as String?),
        version: Value(remote.version),
        syncStatus: const Value('SYNCED'),
      );
      await _db.into(_db.serviceRequests).insertOnConflictUpdate(companion);
    }
  }

  Future<void> _pullQuotes(String companyId) async {
    final remoteRecords = await _api.listQuotes();
    for (final remote in remoteRecords) {
      if (await _hasPendingOutboxFor(remote.id)) continue;

      final local = await (_db.select(
        _db.quotes,
      )..where((q) => q.id.equals(remote.id))).getSingleOrNull();
      if (local != null && local.version >= remote.version) continue;

      final r = remote.raw;
      await _db.transaction(() async {
        await _db
            .into(_db.quotes)
            .insertOnConflictUpdate(
              QuotesCompanion(
                id: Value(remote.id),
                companyId: Value(companyId),
                code: Value(r['code'] as String),
                customerId: Value(r['customer_id'] as String),
                status: Value(r['status'] as String),
                notes: Value(r['notes'] as String?),
                totalMinor: Value((r['total_minor'] as num?)?.toInt() ?? 0),
                introText: Value(r['intro_text'] as String?),
                paymentTerms: Value(r['payment_terms'] as String?),
                deliveryTime: Value(r['delivery_time'] as String?),
                warrantyTerms: Value(r['warranty_terms'] as String?),
                currency: Value(r['currency'] as String? ?? 'TRY'),
                vatMode: Value(r['vat_mode'] as String? ?? 'EXCLUDED'),
                vatRate: Value((r['vat_rate'] as num?)?.toInt() ?? 20),
                validUntil: Value(
                  r['valid_until'] == null
                      ? null
                      : DateTime.parse(r['valid_until'] as String),
                ),
                version: Value(remote.version),
                syncStatus: const Value('SYNCED'),
              ),
            );
        await _replaceDocItems(
          quoteId: remote.id,
          items: (r['items'] as List<dynamic>?) ?? const [],
        );
      });
    }
  }

  Future<void> _pullProformas(String companyId) async {
    final remoteRecords = await _api.listProformas();
    for (final remote in remoteRecords) {
      if (await _hasPendingOutboxFor(remote.id)) continue;

      final local = await (_db.select(
        _db.proformas,
      )..where((p) => p.id.equals(remote.id))).getSingleOrNull();
      if (local != null && local.version >= remote.version) continue;

      final r = remote.raw;
      await _db.transaction(() async {
        await _db
            .into(_db.proformas)
            .insertOnConflictUpdate(
              ProformasCompanion(
                id: Value(remote.id),
                companyId: Value(companyId),
                code: Value(r['code'] as String),
                customerId: Value(r['customer_id'] as String),
                validUntil: Value(
                  r['valid_until'] == null
                      ? null
                      : DateTime.parse(r['valid_until'] as String),
                ),
                notes: Value(r['notes'] as String?),
                totalMinor: Value((r['total_minor'] as num?)?.toInt() ?? 0),
                introText: Value(r['intro_text'] as String?),
                paymentTerms: Value(r['payment_terms'] as String?),
                deliveryTime: Value(r['delivery_time'] as String?),
                warrantyTerms: Value(r['warranty_terms'] as String?),
                currency: Value(r['currency'] as String? ?? 'TRY'),
                vatMode: Value(r['vat_mode'] as String? ?? 'EXCLUDED'),
                vatRate: Value((r['vat_rate'] as num?)?.toInt() ?? 20),
                version: Value(remote.version),
                syncStatus: const Value('SYNCED'),
              ),
            );
        await _replaceDocItems(
          proformaId: remote.id,
          items: (r['items'] as List<dynamic>?) ?? const [],
        );
      });
    }
  }

  /// Cari hesap hareketleri — sunucu TEK doğruluk kaynağıdır.
  ///
  /// Telefon, iş tamamlama/tahsilat anında yerelde "iyimser" bir kayıt
  /// oluşturur (kullanıcı bakiyeyi anında görsün diye). Sunucu da aynı
  /// olay için kendi kaydını üretir. Bu iki kayıt AYNI olayı temsil eder;
  /// pull sırasında yerel iyimser kayıt silinip sunucununki yazılır —
  /// aksi halde aynı borç/alacak iki kez sayılırdı.
  ///
  /// Eşleştirme (referenceType, referenceId) üzerinden yapılır; bu yüzden
  /// mobil tarafın referansı sunucuyla aynı olmak ZORUNDA (tahsilatta
  /// payment id, iş tamamlamada job id — bkz. FinanceRepository).
  Future<void> _pullLedgerEntries(String companyId) async {
    final remoteRecords = await _api.listLedgerEntries();

    await _db.transaction(() async {
      for (final remote in remoteRecords) {
        final r = remote.raw;
        final referenceType = r['reference_type'] as String;
        final referenceId = r['reference_id'] as String?;

        // Aynı olayın iyimser yerel kaydını temizle (sunucudan gelen
        // kaydın kendisi hariç — id'ler farklı olabilir).
        if (referenceId != null) {
          await (_db.delete(_db.customerLedgerEntries)..where(
                (e) =>
                    e.referenceType.equals(referenceType) &
                    e.referenceId.equals(referenceId) &
                    e.syncStatus.equals('PENDING') &
                    e.id.equals(remote.id).not(),
              ))
              .go();
        }

        await _db
            .into(_db.customerLedgerEntries)
            .insertOnConflictUpdate(
              CustomerLedgerEntriesCompanion(
                id: Value(remote.id),
                companyId: Value(companyId),
                customerId: Value(r['customer_id'] as String),
                entryDate: Value(
                  DateTime.parse(r['entry_date'] as String).toLocal(),
                ),
                type: Value(r['type'] as String),
                amountMinor: Value((r['amount_minor'] as num).toInt()),
                referenceType: Value(referenceType),
                referenceId: Value(referenceId),
                description: Value(r['description'] as String),
                syncStatus: const Value('SYNCED'),
              ),
            );
      }
    });
  }

  /// Belge kalemlerini sunucudakiyle bire bir değiştirir — kalemler belge
  /// oluşturulduktan sonra düzenlenemez (immutable), bu yüzden satır bazlı
  /// merge yerine toptan değişim yeterli ve güvenli.
  Future<void> _replaceDocItems({
    String? quoteId,
    String? proformaId,
    required List<dynamic> items,
  }) async {
    if (quoteId != null) {
      await (_db.delete(
        _db.quoteItems,
      )..where((i) => i.quoteId.equals(quoteId))).go();
      for (final raw in items) {
        final item = raw as Map<String, dynamic>;
        await _db
            .into(_db.quoteItems)
            .insertOnConflictUpdate(
              QuoteItemsCompanion(
                id: Value(item['id'] as String),
                quoteId: Value(quoteId),
                description: Value(item['description'] as String),
                quantity: Value((item['quantity'] as num).toInt()),
                unit: Value(item['unit'] as String? ?? 'adet'),
                unitPriceMinor: Value(
                  (item['unit_price_minor'] as num).toInt(),
                ),
                taxRate: Value((item['tax_rate'] as num?)?.toInt() ?? 20),
                discountMinor: Value(
                  (item['discount_minor'] as num?)?.toInt() ?? 0,
                ),
              ),
            );
      }
      return;
    }
    await (_db.delete(
      _db.proformaItems,
    )..where((i) => i.proformaId.equals(proformaId!))).go();
    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      await _db
          .into(_db.proformaItems)
          .insertOnConflictUpdate(
            ProformaItemsCompanion(
              id: Value(item['id'] as String),
              proformaId: Value(proformaId!),
              description: Value(item['description'] as String),
              quantity: Value((item['quantity'] as num).toInt()),
              unit: Value(item['unit'] as String? ?? 'adet'),
              unitPriceMinor: Value((item['unit_price_minor'] as num).toInt()),
              taxRate: Value((item['tax_rate'] as num?)?.toInt() ?? 20),
              discountMinor: Value(
                (item['discount_minor'] as num?)?.toInt() ?? 0,
              ),
            ),
          );
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ref.watch(databaseProvider),
    ref.watch(syncApiClientProvider),
    ref.watch(tokenStoreProvider),
  );
});
