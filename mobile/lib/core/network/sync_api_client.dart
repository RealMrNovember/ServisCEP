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
    );
  }

  final String token;
  final String userId;
  final String companyId;
  final String fullName;
  final String companyName;
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

  Future<SyncEntityResult> createCustomer(Map<String, dynamic> payload);
  Future<SyncEntityResult> updateCustomer(
    String id,
    Map<String, dynamic> payload,
  );
  Future<void> deleteCustomer(String id);
  Future<List<RemoteRecord>> listCustomers();

  Future<SyncEntityResult> createJob(Map<String, dynamic> payload);
  Future<SyncEntityResult> updateJob(String id, Map<String, dynamic> payload);
  Future<List<RemoteRecord>> listJobs();
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
  Future<SyncEntityResult> createJob(Map<String, dynamic> payload) =>
      _create('/jobs', payload);

  @override
  Future<SyncEntityResult> updateJob(String id, Map<String, dynamic> payload) =>
      _update('/jobs/$id', payload);

  @override
  Future<List<RemoteRecord>> listJobs() => _listAllPages('/jobs');

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
