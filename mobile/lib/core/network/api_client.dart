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
///
/// TARİHÇE — burada `HttpClient.connectionFactory` ile IPv4'ü tercih eden
/// bir katman vardı ve TÜM ağ trafiğini kırdı: Dart'ta bu geri çağrım
/// kullanıldığında HTTPS için `SecureSocket` döndürülmesi gerekiyor, düz
/// `Socket` döndürülünce uygulama 443 portuna şifresiz konuşmaya çalışıyor
/// ve hiçbir istek kurulamıyor. Sunucu logları 11 saat boyunca tek bir
/// istek görmedi.
///
/// Eklenme gerekçesi de zaten yanlıştı: bir cihazda giriş yapılamamasının
/// sebebi IPv6 değil, bozulmuş güvenli depoydu (bkz. TokenStore).
/// Kanıtlanmamış bir teori için ağ katmanına dokunulmamalı — burası birim
/// testleriyle doğrulanamıyor.
class ApiClient {
  ApiClient(this._tokenStore) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        // Google ile giriş sırasında sunucu, kimliği doğrulamak için ayrıca
        // Google'a gidiyor; mobil veride bu zincir 20 saniyeyi aşabiliyor ve
        // zaman aşımı kullanıcıya "internet yok" gibi görünüyordu.
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 45),
        headers: {'Accept': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Buradan fırlayan HER hata, Dio tarafından yanıtsız bir
          // `DioException`'a çevrilir ve uygulamada ağ hatasından ayırt
          // edilemez. Token okunamıyorsa istek yine de atılır; sunucu 401
          // döner ve kullanıcı yeniden giriş yapar.
          try {
            final token = await _tokenStore.read();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } on Object {
            // Yetkisiz devam edilir.
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
