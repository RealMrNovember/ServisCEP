import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// Backend'in `/auth/register` ve `/auth/login` yanıtı (bkz.
/// backend/app/Http/Controllers/Api/V1/AuthController.php@tokenResponse).
class AuthTokenResult {
  AuthTokenResult({
    required this.token,
    required this.userId,
    required this.companyId,
    required this.fullName,
    required this.companyName,
    required this.role,
  });

  factory AuthTokenResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final company = data['company'] as Map<String, dynamic>;
    return AuthTokenResult(
      token: json['token'] as String,
      userId: data['id'] as String,
      companyId: company['id'] as String,
      fullName: data['full_name'] as String,
      companyName: company['name'] as String,
      // Sunucu rolü döndürmezse en kısıtlayıcı değil, varsayılan OWNER
      // alınır: tek kullanıcılı kayıtlarda (register) sahip zaten odur.
      role: data['role'] as String? ?? 'OWNER',
    );
  }

  final String token;
  final String userId;
  final String companyId;
  final String fullName;
  final String companyName;
  final String role;
}

/// Backend'in bir kaydın son hâlini + `version`'ını döndüren yanıtları için
/// ortak sonuç tipi (Customer/Job create-update).
class SyncEntityResult {
  SyncEntityResult({required this.id, required this.version});

  factory SyncEntityResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return SyncEntityResult(
      id: data['id'] as String,
      // Bazı response'larda version yer almayabilir (ör. eski Resource'lar) —
      // yoksa 1 varsayılır, bir sonraki pull bunu düzeltir.
      version: (data['version'] as num?)?.toInt() ?? 1,
    );
  }

  final String id;
  final int version;
}

/// Sunucudan çekilen (pull) tek bir Customer/Job satırı — sadece merge
/// kararı için gereken alanlar.
class RemoteRecord {
  RemoteRecord({required this.id, required this.version, required this.raw});
  final String id;
  final int version;
  final Map<String, dynamic> raw;
}

/// `SyncService`'in ihtiyaç duyduğu backend çağrılarının arayüzü — gerçek
/// implementasyon Dio kullanır, testlerde elle yazılmış bir sahte
/// (`FakeSyncApiClient`) kullanılır (bkz. dart/testing.md "Fakes Over
/// Mocks").
abstract interface class SyncApiClient {
  Future<AuthTokenResult> register({
    required String companyName,
    String? businessTypes,
    required String fullName,
    required String email,
    String? phone,
    required String password,
  });

  Future<AuthTokenResult> login({
    required String email,
    required String password,
  });

  /// Hesap zaten var olmalı — yoksa backend 422 döner (bkz. LoginScreen'in
  /// bunu yakalayıp onboarding'e yönlendirmesi).
  Future<AuthTokenResult> loginWithGoogle(String idToken);

  /// Onboarding'in Google akışı — hesap ZATEN varsa backend 422 döner.
  Future<AuthTokenResult> registerWithGoogle({
    required String idToken,
    required String companyName,
    String? businessTypes,
    String? phone,
  });

  Future<SyncEntityResult> createCustomer(Map<String, dynamic> payload);
  Future<SyncEntityResult> updateCustomer(
    String id,
    Map<String, dynamic> payload,
  );
  Future<void> deleteCustomer(String id);
  Future<List<RemoteRecord>> listCustomers();

  /// Sunucudaki çöp kutusu (soft-deleted müşteriler) — tombstone senkronu
  /// için: ofiste silinen müşteri telefonda da silinsin.
  Future<List<RemoteRecord>> listTrashedCustomers();

  /// Vergi levhası yükleme (multipart) — müşteri başına tek dosya, yeni
  /// yükleme öncekinin yerine geçer.
  Future<void> uploadTaxCertificate(String customerId, String filePath);

  Future<SyncEntityResult> createJob(Map<String, dynamic> payload);
  Future<SyncEntityResult> updateJob(String id, Map<String, dynamic> payload);
  Future<List<RemoteRecord>> listJobs();

  Future<SyncEntityResult> createServiceRequest(Map<String, dynamic> payload);

  /// Talep → iş dönüşümü — backend'in `/convert` endpoint'i, mobilin offline
  /// oluşturduğu işin UUID'sini (`job_id`) kabul eder; yanıt işin son hâli
  /// (JobResource). Replay idempotenttir (200 döner, duplicate iş oluşmaz).
  Future<Map<String, dynamic>> convertServiceRequest(
    String id,
    String jobId,
  );
  Future<List<RemoteRecord>> listServiceRequests();

  Future<SyncEntityResult> createQuote(Map<String, dynamic> payload);
  Future<SyncEntityResult> updateQuote(String id, Map<String, dynamic> payload);
  Future<List<RemoteRecord>> listQuotes();

  Future<SyncEntityResult> createProforma(Map<String, dynamic> payload);
  Future<List<RemoteRecord>> listProformas();

  /// Tahsilat müşteri altına yuvalı: POST /customers/{customerId}/payments.
  Future<SyncEntityResult> createPayment(
    String customerId,
    Map<String, dynamic> payload,
  );
  Future<SyncEntityResult> createIncomeEntry(Map<String, dynamic> payload);
  Future<SyncEntityResult> createExpenseEntry(Map<String, dynamic> payload);

  Future<SyncEntityResult> createJobNote(
    String jobId,
    Map<String, dynamic> payload,
  );

  /// Fotoğraf yerel dosyadan multipart olarak yüklenir — payload'da binary
  /// taşınmaz, dosya gönderim anında diskten okunur (bkz. sync_service).
  Future<SyncEntityResult> createJobPhoto(
    String jobId, {
    required String id,
    required String category,
    required String filePath,
  });

  Future<SyncEntityResult> createJobSignature(
    String jobId, {
    required String id,
    required String signerName,
    required String filePath,
  });

  /// Şirket ayarları güncellemesi (bkz. CompanyController).
  Future<void> updateCompany(Map<String, dynamic> payload);

  /// Kendi profili — ad/telefon.
  Future<void> updateProfile(Map<String, dynamic> payload);

  /// Parola değiştirme; mevcut parola doğrulanır (bkz. ProfileController).
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Cari hesap hareketleri — sunucu tek doğruluk kaynağıdır, bu yüzden
  /// yalnızca PULL edilir (bkz. LedgerEntryController).
  Future<List<RemoteRecord>> listLedgerEntries();

  /// Personel yönetimi (yalnızca işletme sahibi).
  Future<List<Map<String, dynamic>>> listPersonnel();
  Future<Map<String, dynamic>> createPersonnel(Map<String, dynamic> payload);
  Future<void> updatePersonnel(String id, Map<String, dynamic> payload);
  Future<void> deletePersonnel(String id);

  /// Bekleyen senkron çakışmaları (OWNER-only, bkz. SyncConflictController).
  Future<List<Map<String, dynamic>>> listPendingConflicts();

  /// [resolution]: SUNUCU_TUTULDU | MOBIL_TUTULDU.
  Future<void> resolveConflict(String conflictId, String resolution);
}

class DioSyncApiClient implements SyncApiClient {
  DioSyncApiClient(this._client);

  final ApiClient _client;
  Dio get _dio => _client.dio;

  @override
  Future<AuthTokenResult> register({
    required String companyName,
    String? businessTypes,
    required String fullName,
    required String email,
    String? phone,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'company_name': companyName,
          // Backend'de 'nullable' — açıkça null geçmek, alanı hiç
          // göndermemekle aynı sonucu verir.
          'business_types': businessTypes,
          'full_name': fullName,
          'email': email,
          'phone': phone,
          'password': password,
          'password_confirmation': password,
        },
      );
      return AuthTokenResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  @override
  Future<AuthTokenResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return AuthTokenResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  @override
  Future<AuthTokenResult> loginWithGoogle(String idToken) async {
    try {
      final response = await _dio.post(
        '/auth/google/login',
        data: {'id_token': idToken},
      );
      return AuthTokenResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  @override
  Future<AuthTokenResult> registerWithGoogle({
    required String idToken,
    required String companyName,
    String? businessTypes,
    String? phone,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/google/register',
        data: {
          'id_token': idToken,
          'company_name': companyName,
          'business_types': businessTypes,
          'phone': phone,
        },
      );
      return AuthTokenResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  @override
  Future<SyncEntityResult> createCustomer(Map<String, dynamic> payload) =>
      _create('/customers', payload);

  @override
  Future<SyncEntityResult> updateCustomer(
    String id,
    Map<String, dynamic> payload,
  ) => _update('/customers/$id', payload);

  @override
  Future<void> deleteCustomer(String id) async {
    try {
      await _dio.delete('/customers/$id');
    } on DioException catch (e) {
      // Zaten silinmiş (3 günlük çöp kutusu penceresi içinde bile olsa,
      // ör. iki cihaz aynı kaydı sildi) — idempotent kabul edilir.
      if (e.response?.statusCode == 404) return;
      _client.throwApiException(e);
    }
  }

  @override
  Future<List<RemoteRecord>> listCustomers() => _listAllPages('/customers');

  @override
  Future<List<RemoteRecord>> listTrashedCustomers() =>
      _listAllPages('/customers/trash');

  @override
  Future<void> uploadTaxCertificate(String customerId, String filePath) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      await _dio.post('/customers/$customerId/tax-certificate', data: form);
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  @override
  Future<SyncEntityResult> createJob(Map<String, dynamic> payload) =>
      _create('/jobs', payload);

  @override
  Future<SyncEntityResult> updateJob(String id, Map<String, dynamic> payload) =>
      _update('/jobs/$id', payload);

  @override
  Future<List<RemoteRecord>> listJobs() => _listAllPages('/jobs');

  @override
  Future<SyncEntityResult> createServiceRequest(Map<String, dynamic> payload) =>
      _create('/service-requests', payload);

  @override
  Future<Map<String, dynamic>> convertServiceRequest(
    String id,
    String jobId,
  ) async {
    try {
      final response = await _dio.post(
        '/service-requests/$id/convert',
        data: {'job_id': jobId},
      );
      final body = response.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  @override
  Future<List<RemoteRecord>> listServiceRequests() =>
      _listAllPages('/service-requests');

  @override
  Future<SyncEntityResult> createQuote(Map<String, dynamic> payload) =>
      _create('/quotes', payload);

  @override
  Future<SyncEntityResult> updateQuote(
    String id,
    Map<String, dynamic> payload,
  ) => _update('/quotes/$id', payload);

  @override
  Future<List<RemoteRecord>> listQuotes() => _listAllPages('/quotes');

  @override
  Future<SyncEntityResult> createProforma(Map<String, dynamic> payload) =>
      _create('/proformas', payload);

  @override
  Future<List<RemoteRecord>> listProformas() => _listAllPages('/proformas');

  @override
  Future<SyncEntityResult> createPayment(
    String customerId,
    Map<String, dynamic> payload,
  ) => _create('/customers/$customerId/payments', payload);

  @override
  Future<SyncEntityResult> createIncomeEntry(Map<String, dynamic> payload) =>
      _create('/income-entries', payload);

  @override
  Future<SyncEntityResult> createExpenseEntry(Map<String, dynamic> payload) =>
      _create('/expense-entries', payload);

  @override
  Future<SyncEntityResult> createJobNote(
    String jobId,
    Map<String, dynamic> payload,
  ) => _create('/jobs/$jobId/notes', payload);

  @override
  Future<SyncEntityResult> createJobPhoto(
    String jobId, {
    required String id,
    required String category,
    required String filePath,
  }) => _upload('/jobs/$jobId/photos', {
    'id': id,
    'category': category,
  }, filePath);

  @override
  Future<SyncEntityResult> createJobSignature(
    String jobId, {
    required String id,
    required String signerName,
    required String filePath,
  }) => _upload('/jobs/$jobId/signatures', {
    'id': id,
    'signer_name': signerName,
  }, filePath);

  @override
  Future<void> updateCompany(Map<String, dynamic> payload) async {
    try {
      await _dio.put('/company', data: payload);
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  @override
  Future<void> updateProfile(Map<String, dynamic> payload) async {
    try {
      await _dio.put('/auth/profile', data: payload);
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  @override
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.put('/auth/password', data: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': newPassword,
      });
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  @override
  Future<List<RemoteRecord>> listLedgerEntries() =>
      _listAllPages('/ledger-entries');

  @override
  Future<List<Map<String, dynamic>>> listPersonnel() async {
    try {
      final response = await _dio.get('/personnel');
      final data =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  @override
  Future<Map<String, dynamic>> createPersonnel(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post('/personnel', data: payload);
      return (response.data as Map<String, dynamic>)['data']
          as Map<String, dynamic>;
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  @override
  Future<void> updatePersonnel(String id, Map<String, dynamic> payload) async {
    try {
      await _dio.put('/personnel/$id', data: payload);
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  @override
  Future<void> deletePersonnel(String id) async {
    try {
      await _dio.delete('/personnel/$id');
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listPendingConflicts() async {
    try {
      final response = await _dio.get(
        '/sync-conflicts',
        queryParameters: {'resolution': 'BEKLIYOR'},
      );
      final data =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  @override
  Future<void> resolveConflict(String conflictId, String resolution) async {
    try {
      await _dio.post(
        '/sync-conflicts/$conflictId/resolve',
        data: {'resolution': resolution},
      );
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  Future<SyncEntityResult> _upload(
    String path,
    Map<String, dynamic> fields,
    String filePath,
  ) async {
    try {
      final form = FormData.fromMap({
        ...fields,
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post(path, data: form);
      return SyncEntityResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  Future<SyncEntityResult> _create(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post(path, data: payload);
      return SyncEntityResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  Future<SyncEntityResult> _update(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.put(path, data: payload);
      return SyncEntityResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  Future<List<RemoteRecord>> _listAllPages(String path) async {
    final records = <RemoteRecord>[];
    var page = 1;
    while (true) {
      try {
        final response = await _dio.get(path, queryParameters: {'page': page});
        final body = response.data as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>;
        records.addAll(
          data.map(
            (raw) => RemoteRecord(
              id: (raw as Map<String, dynamic>)['id'] as String,
              version: (raw['version'] as num?)?.toInt() ?? 1,
              raw: raw,
            ),
          ),
        );
        final meta = body['meta'] as Map<String, dynamic>?;
        final lastPage = (meta?['last_page'] as num?)?.toInt() ?? page;
        if (page >= lastPage) break;
        page++;
      } on DioException catch (e) {
        _client.throwApiException(e);
      }
    }
    return records;
  }
}

final syncApiClientProvider = Provider<SyncApiClient>((ref) {
  return DioSyncApiClient(ref.watch(apiClientProvider));
});
