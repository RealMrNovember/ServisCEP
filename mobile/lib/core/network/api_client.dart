import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'token_store.dart';

/// Backend'in genel hata gövdesi (`{"message": "...", "errors": {...}}`).
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.body});
  final int? statusCode;
  final String message;
  final Map<String, dynamic>? body;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// 409 — sürüm çakışması. Gövde, backend'in `SyncConflictResource`'ı
/// (base_version/server_version/server_snapshot) taşır — bkz.
/// backend/app/Http/Resources/SyncConflictResource.php.
class ApiConflictException extends ApiException {
  ApiConflictException(Map<String, dynamic>? body)
    : super(409, 'Sürüm çakışması', body: body);

  Map<String, dynamic>? get serverSnapshot =>
      body?['data']?['server_snapshot'] as Map<String, dynamic>?;
}

/// Paylaşılan Dio örneği — base URL, auth header'ı (TokenStore'dan) ve JSON
/// header'ları tek yerde kurulur. `SyncApiClient` bunun üzerine yazılır.
class ApiClient {
  ApiClient(this._tokenStore) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStore.read();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final TokenStore _tokenStore;
  late final Dio _dio;

  Dio get dio => _dio;

  /// `DioException`'ı uygulamanın kendi tipine çevirir — çağıranlar Dio'ya
  /// değil bu tiplere bağımlı olur.
  Never throwApiException(DioException e) {
    final response = e.response;
    if (response == null) {
      throw ApiException(null, 'Ağ hatası: ${e.message}');
    }
    final body = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : null;
    if (response.statusCode == 409) {
      throw ApiConflictException(body);
    }
    throw ApiException(
      response.statusCode,
      body?['message'] as String? ?? 'Sunucu hatası',
      body: body,
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(tokenStoreProvider));
});
