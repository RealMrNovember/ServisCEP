import 'package:drift/drift.dart';

/// TeknikCEP yerel veritabanı şeması (Drift).
///
/// Bkz. docs/07 § Veritabanı Ana Modeli — bu tablolar, backend PostgreSQL
/// şemasının yerel/offline karşılığıdır. Alan adları backend ile bilinçli
/// olarak tutarlı tutulmuştur ki senkronizasyon (Phase 17) katmanı eklenirken
/// eşleme basit olsun.
///
/// Tüm kayıtlar client-side üretilen UUID id kullanır (autoincrement DEĞİL)
/// — offline-first mimaride birden fazla cihaz aynı anda kayıt oluşturabilir,
/// bu yüzden id çakışması olmamalı (bkz. docs/08).
///
/// `syncStatus` alanı şimdiden eklenmiştir (PENDING/SYNCED/FAILED) ancak
/// senkronizasyon motoru henüz bağlı değildir (Phase 17) — veri modelinde
/// "sonra düzeltiriz" yaklaşımı kullanılmaz (bkz. docs/11).

class Companies extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Virgülle ayrılmış işletme türleri (Elektrik, Kamera, Bilgisayar, ...)
  TextColumn get businessTypes => text().withDefault(const Constant(''))();
  TextColumn get iban => text().nullable()();

  /// Belge antedinde görünen bilgiler (bkz. PdfService).
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get taxInfo => text().nullable()();

  /// Belge metinleri için şirket varsayılanları — her teklifte yeniden
  /// yazılmasın diye. Belge oluşturulurken kopyalanır.
  TextColumn get introText => text().nullable()();
  TextColumn get paymentTerms => text().nullable()();
  TextColumn get deliveryTime => text().nullable()();
  TextColumn get warrantyTerms => text().nullable()();

  /// Logonun YEREL kopyasının yolu (kırpılmış hâli).
  TextColumn get logoPath => text().nullable()();
  BoolColumn get hasLogo => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().references(Companies, #id)();
  TextColumn get fullName => text()();
  TextColumn get email => text().unique()();
  TextColumn get phone => text().nullable()();
  TextColumn get passwordHash => text()();

  /// OWNER / ADMIN / TECHNICIAN / ACCOUNTING / VIEWER — MVP'de yalnızca OWNER.
  TextColumn get role => text().withDefault(const Constant('OWNER'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().references(Companies, #id)();
  TextColumn get code => text()();

  /// Yetkili adı soyadı ve firma adı ayrı alanlardır — ikisinden en az biri
  /// dolu olmalıdır (bkz. customer_form_screen.dart doğrulaması), aynı anda
  /// ikisini birden girmek zorunlu değildir.
  TextColumn get contactName => text().nullable()();
  TextColumn get companyName => text().nullable()();
  TextColumn get iban => text().nullable()();

  /// BIREYSEL / FIRMA / APARTMAN / SITE / KAMU / DIGER
  TextColumn get type => text().withDefault(const Constant('BIREYSEL'))();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get il => text().nullable()();
  TextColumn get ilce => text().nullable()();
  TextColumn get taxInfo => text().nullable()();

  /// Vergi levhasının YEREL kopyasının yolu (kamerayla çekilip yüklendiyse).
  TextColumn get taxCertificatePath => text().nullable()();

  /// Sunucuda kayıtlı bir vergi levhası var mı — pull ile güncellenir
  /// (web panelden yüklenen belgeler de böyle görünür).
  BoolColumn get hasTaxCertificate =>
      boolean().withDefault(const Constant(false))();

  /// Müşteri logosu — belgede karşı tarafın markası (opsiyonel).
  TextColumn get logoPath => text().nullable()();
  BoolColumn get hasLogo => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  TextColumn get tags => text().nullable()();

  /// PENDING / SYNCED / CONFLICT / FAILED — bkz. `core/sync/sync_service.dart`.
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();

  /// Sunucudaki `version` sayacının yerel kopyası — optimistic concurrency
  /// için `base_version` olarak gönderilir (bkz. backend `HasVersion`).
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class JobTypes extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().references(Companies, #id)();
  TextColumn get category => text()();
  TextColumn get name => text()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class ServiceRequests extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().references(Companies, #id)();
  TextColumn get code => text()();
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get description => text()();

  /// YUKSEK / NORMAL / DUSUK
  TextColumn get priority => text().withDefault(const Constant('NORMAL'))();
  TextColumn get address => text().nullable()();

  /// BEKLIYOR / ISLEME_ALINDI / REDDEDILDI / ISE_DONUSTU
  TextColumn get status => text().withDefault(const Constant('BEKLIYOR'))();
  TextColumn get convertedJobId => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();

  /// Sunucudaki `version` sayacının yerel kopyası (bkz. backend `HasVersion`).
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Jobs extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().references(Companies, #id)();
  TextColumn get code => text()();
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get jobTypeId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get address => text().nullable()();
  DateTimeColumn get appointmentDate => dateTime().nullable()();
  TextColumn get startTime => text().nullable()();
  TextColumn get endTime => text().nullable()();

  /// YUKSEK / NORMAL / DUSUK
  TextColumn get priority => text().withDefault(const Constant('NORMAL'))();

  /// TALEP / PLANLANDI / DEVAM_EDIYOR / BEKLEMEDE / TAMAMLANDI / IPTAL
  TextColumn get status => text().withDefault(const Constant('TALEP'))();
  TextColumn get technicianUserId => text().nullable()();
  IntColumn get estimatedPriceMinor => integer().nullable()();
  IntColumn get actualPriceMinor => integer().nullable()();
  TextColumn get notes => text().nullable()();

  /// PENDING / SYNCED / CONFLICT / FAILED — bkz. `core/sync/sync_service.dart`.
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();

  /// Sunucudaki `version` sayacının yerel kopyası — optimistic concurrency
  /// için `base_version` olarak gönderilir (bkz. backend `HasVersion`).
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class JobNotes extends Table {
  TextColumn get id => text()();
  TextColumn get jobId => text().references(Jobs, #id)();
  TextColumn get note => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class JobPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get jobId => text().references(Jobs, #id)();

  /// ONCESI / ARIZA / MONTAJ / SONRASI / MALZEME / DIGER
  TextColumn get category => text().withDefault(const Constant('DIGER'))();
  TextColumn get filePath => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class JobSignatures extends Table {
  TextColumn get id => text()();
  TextColumn get jobId => text().references(Jobs, #id)();
  TextColumn get signerName => text()();
  TextColumn get filePath => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Quotes extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().references(Companies, #id)();
  TextColumn get code => text()();
  TextColumn get customerId => text().references(Customers, #id)();

  /// TASLAK / GONDERILDI / BEKLEMEDE / KABUL_EDILDI / REDDEDILDI / SURESI_DOLDU
  TextColumn get status => text().withDefault(const Constant('TASLAK'))();
  TextColumn get notes => text().nullable()();
  IntColumn get totalMinor => integer().withDefault(const Constant(0))();


  /// Belgenin giriş yazısı ve şartları.
  ///
  /// Şirket ayarlarındaki varsayılanlar belge OLUŞTURULURKEN kopyalanır;
  /// sonradan ayar değişse bile gönderilmiş bir teklifin şartları
  /// kendiliğinden değişmez.
  TextColumn get introText => text().nullable()();
  TextColumn get paymentTerms => text().nullable()();
  TextColumn get deliveryTime => text().nullable()();
  TextColumn get warrantyTerms => text().nullable()();

  /// TRY / USD / EUR — kur DÖNÜŞÜMÜ yapılmaz, bkz. core/utils/money.dart.
  TextColumn get currency => text().withDefault(const Constant('TRY'))();

  /// EXCLUDED ("+ KDV") / INCLUDED ("KDV dahil").
  TextColumn get vatMode => text().withDefault(const Constant('EXCLUDED'))();

  /// Belge geneli varsayılan KDV oranı; kalemler kendi oranını taşır.
  IntColumn get vatRate => integer().withDefault(const Constant(20))();
  DateTimeColumn get validUntil => dateTime().nullable()();

  /// PENDING / SYNCED / CONFLICT / FAILED — bkz. `core/sync/sync_service.dart`.
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();

  /// Sunucudaki `version` sayacının yerel kopyası (bkz. backend `HasVersion`).
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class QuoteItems extends Table {
  TextColumn get id => text()();
  TextColumn get quoteId => text().references(Quotes, #id)();
  TextColumn get description => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  TextColumn get unit => text().withDefault(const Constant('adet'))();
  IntColumn get unitPriceMinor => integer().withDefault(const Constant(0))();
  IntColumn get taxRate => integer().withDefault(const Constant(20))();
  IntColumn get discountMinor => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Proformas extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().references(Companies, #id)();
  TextColumn get code => text()();
  TextColumn get customerId => text().references(Customers, #id)();
  DateTimeColumn get validUntil => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get totalMinor => integer().withDefault(const Constant(0))();


  /// Belgenin giriş yazısı ve şartları.
  ///
  /// Şirket ayarlarındaki varsayılanlar belge OLUŞTURULURKEN kopyalanır;
  /// sonradan ayar değişse bile gönderilmiş bir teklifin şartları
  /// kendiliğinden değişmez.
  TextColumn get introText => text().nullable()();
  TextColumn get paymentTerms => text().nullable()();
  TextColumn get deliveryTime => text().nullable()();
  TextColumn get warrantyTerms => text().nullable()();

  /// TRY / USD / EUR — bkz. core/utils/money.dart.
  TextColumn get currency => text().withDefault(const Constant('TRY'))();
  TextColumn get vatMode => text().withDefault(const Constant('EXCLUDED'))();
  IntColumn get vatRate => integer().withDefault(const Constant(20))();

  /// PENDING / SYNCED / CONFLICT / FAILED — bkz. `core/sync/sync_service.dart`.
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();

  /// Sunucudaki `version` sayacının yerel kopyası (bkz. backend `HasVersion`).
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ProformaItems extends Table {
  TextColumn get id => text()();
  TextColumn get proformaId => text().references(Proformas, #id)();
  TextColumn get description => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  TextColumn get unit => text().withDefault(const Constant('adet'))();
  IntColumn get unitPriceMinor => integer().withDefault(const Constant(0))();
  IntColumn get taxRate => integer().withDefault(const Constant(20))();
  IntColumn get discountMinor => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().references(Companies, #id)();
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get jobId => text().nullable()();
  IntColumn get amountMinor => integer()();
  TextColumn get method => text().withDefault(const Constant('Nakit'))();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class IncomeEntries extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().references(Companies, #id)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get description => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get jobId => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('Diğer'))();
  IntColumn get amountMinor => integer()();
  TextColumn get method => text().withDefault(const Constant('Nakit'))();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ExpenseEntries extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().references(Companies, #id)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get description => text()();
  TextColumn get category => text().withDefault(const Constant('Diğer'))();
  IntColumn get amountMinor => integer()();
  TextColumn get vendorName => text().nullable()();
  TextColumn get receiptPhotoPath => text().nullable()();
  TextColumn get method => text().withDefault(const Constant('Nakit'))();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Ürün / stok kataloğu — bkz. docs/16-stok-ve-barkod.md.
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().references(Companies, #id)();

  /// Taranan barkod (EAN-13/UPC-A vb.) — her ürünün olmak zorunda değil.
  TextColumn get barcode => text().nullable()();
  TextColumn get sku => text().nullable()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get unit => text().withDefault(const Constant('adet'))();
  IntColumn get purchasePriceMinor =>
      integer().withDefault(const Constant(0))();
  IntColumn get salePriceMinor => integer().withDefault(const Constant(0))();
  IntColumn get currentStock => integer().withDefault(const Constant(0))();
  IntColumn get minStock => integer().withDefault(const Constant(0))();

  /// MANUAL / GLOBAL_LOOKUP — ürün nasıl oluşturuldu (izlenebilirlik).
  TextColumn get source => text().withDefault(const Constant('MANUAL'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stok hareketleri — immutable, cari hesapla aynı felsefe (bkz. docs/16).
class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().references(Companies, #id)();
  TextColumn get productId => text().references(Products, #id)();

  /// IN (giriş) / OUT (çıkış)
  TextColumn get type => text()();
  IntColumn get quantity => integer()();

  /// job / manual_adjustment / purchase
  TextColumn get referenceType => text()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Senkronizasyon kuyruğu (outbox) — bkz. ROADMAP.md § B10 mobil senkron
/// motoru. Bir Customer/Job yerelde yazıldığında AYNI transaction içinde
/// buraya bir satır düşer; `SyncService` bu satırları sırayla backend'e
/// gönderir. Bir yazma asla kuyruk satırı olmadan yerelde kalmaz — bu,
/// "telefon offline yazdı ama hiç senkron kuyruğuna girmedi" riskini yapısal
/// olarak ortadan kaldırır.
class SyncOperations extends Table {
  TextColumn get id => text()();

  /// customer / job / service_request / quote / proforma / payment /
  /// income_entry / expense_entry
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  /// CREATE / UPDATE / DELETE / CONVERT (yalnızca service_request —
  /// backend'in /convert endpoint'ine gider, bkz. sync_service.dart)
  TextColumn get operation => text()();

  /// Gönderilecek alanların JSON gövdesi.
  TextColumn get payload => text()();

  /// UPDATE için — çakışma tespiti amacıyla yazma anındaki yerel version.
  IntColumn get baseVersion => integer().nullable()();

  /// PENDING / CONFLICT / FAILED — başarılı denemeler satırı SİLER, tabloda
  /// tutulmaz.
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cari hesap hareketleri — bkz. docs/15-cari-hesap.md.
class CustomerLedgerEntries extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().references(Companies, #id)();
  TextColumn get customerId => text().references(Customers, #id)();
  DateTimeColumn get entryDate => dateTime().withDefault(currentDateAndTime)();

  /// DEBIT (borç) / CREDIT (alacak)
  TextColumn get type => text()();
  IntColumn get amountMinor => integer()();

  /// job / payment / manual_adjustment / opening_balance
  TextColumn get referenceType => text()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get description => text()();

  /// PENDING: telefonun İYİMSER olarak oluşturduğu yerel kayıt — kullanıcı
  /// işi tamamlar tamamlamaz bakiyeyi görebilsin diye anında yazılır.
  /// SYNCED: sunucudan çekilmiş, doğruluk kaynağı olan kayıt.
  ///
  /// Cari hesabın tek doğruluk kaynağı SUNUCUDUR (bkz. SyncService.
  /// _pullLedgerEntries): pull sırasında aynı olayı temsil eden iyimser
  /// yerel kayıt, sunucudakiyle DEĞİŞTİRİLİR. Böylece iki taraf bağımsız
  /// hesaplarken bakiyelerin sessizce ayrışması riski ortadan kalkar.
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
