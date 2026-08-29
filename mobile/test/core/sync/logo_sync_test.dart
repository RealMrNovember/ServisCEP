import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/core/database/app_database.dart';
import 'package:serviscep/core/sync/sync_service.dart';

import '../../support/fake_sync_api_client.dart';
import '../../support/fake_token_store.dart';
import '../../support/in_memory_database.dart';

const _companyId = 'company-1';

/// Logo gönderiminin kuyrukta takılı kalmaması.
///
/// Yaşanan hata: [MediaStorage.writeLogo] aynı sahibin eski dosyalarını
/// siliyor. Logo ikinci kez yazıldığında (kullanıcı değiştirince ya da
/// pull eksik dosyayı sunucudan geri indirince) ilk kuyruk satırının
/// işaret ettiği dosya yok oluyor, satır KALICI hataya alınıyor ve
/// yeniden denemek dahil hiçbir şey onu kurtaramıyordu.
void main() {
  late AppDatabase db;
  late FakeSyncApiClient api;
  late Directory gecici;

  setUp(() async {
    db = createInMemoryDatabase();
    api = FakeSyncApiClient();
    gecici = await Directory.systemTemp.createTemp('logo_sync_test');
    await db
        .into(db.companies)
        .insert(CompaniesCompanion.insert(id: _companyId, name: 'Test Co'));
  });

  tearDown(() async {
    await db.close();
    if (gecici.existsSync()) await gecici.delete(recursive: true);
  });

  SyncService buildService() =>
      SyncService(db, api, FakeTokenStore(initialToken: 'test-token'));

  Future<File> logoYaz(String ad) async {
    final dosya = File('${gecici.path}/$ad');
    await dosya.writeAsBytes([1, 2, 3]);
    return dosya;
  }

  Future<void> kuyrugaKoy(String payloadYolu) {
    return db
        .into(db.syncOperations)
        .insert(
          SyncOperationsCompanion.insert(
            id: 'op-1',
            entityType: 'company',
            entityId: _companyId,
            operation: 'LOGO',
            payload: jsonEncode({'file_path': payloadYolu}),
          ),
        );
  }

  Future<void> logoyuAyarla(String? yol) {
    return (db.update(db.companies)
          ..where((c) => c.id.equals(_companyId)))
        .write(CompaniesCompanion(logoPath: Value(yol)));
  }

  test('kuyruktaki yol eskimişse GÜNCEL logo gönderilir', () async {
    // Kullanıcı logoyu iki kez yazdı: eski dosya silindi, yenisi duruyor.
    final yeni = await logoYaz('yeni.png');
    await kuyrugaKoy('${gecici.path}/silinmis.png');
    await logoyuAyarla(yeni.path);

    await buildService().runOnce(_companyId);

    expect(api.uploadCompanyLogoCalls, [yeni.path]);
    final kalan = await db.select(db.syncOperations).get();
    expect(kalan, isEmpty, reason: 'Satır gönderildikten sonra silinmeli.');
  });

  test('logo gerçekten yoksa satır kalıcı hataya değil SİLMEYE döner',
      () async {
    // Dosya da kayıt da yok: sunucudaki logo silinmeli. Eskiden bu durum
    // satırı sonsuza dek FAILED'de bırakıyordu.
    await kuyrugaKoy('${gecici.path}/silinmis.png');
    await logoyuAyarla(null);

    await buildService().runOnce(_companyId);

    expect(api.deleteCompanyLogoCalls, 1);
    expect(api.uploadCompanyLogoCalls, isEmpty);
    final kalan = await db.select(db.syncOperations).get();
    expect(kalan, isEmpty);
  });

  test('kayıtta yol var ama dosya diskte yoksa kuyruk tıkanmaz', () async {
    await kuyrugaKoy('${gecici.path}/silinmis.png');
    await logoyuAyarla('${gecici.path}/o-da-yok.png');

    await buildService().runOnce(_companyId);

    // Kilitlenmemek asıl mesele: satır bir şekilde çözülmeli.
    final kalan = await db.select(db.syncOperations).get();
    expect(kalan, isEmpty);
    expect(api.deleteCompanyLogoCalls, 1);
  });
}
