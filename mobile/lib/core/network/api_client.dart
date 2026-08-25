import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
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
        // Google ile giriş sırasında sunucu, kimliği doğrulamak için ayrıca
        // Google'a gidiyor; mobil veride bu zincir 20 saniyeyi aşabiliyor ve
        // zaman aşımı kullanıcıya "internet yok" gibi görünüyordu.
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 45),
        headers: {'Accept': 'application/json'},
      ),
    );
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: _createHttpClient,
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

  /// Bağlantıyı IPv4 üzerinden kurmayı dener.
  ///
  /// Sebep: sunucu Cloudflare arkasında ve hem A hem AAAA kaydı var. Bazı
  /// mobil operatörlerde IPv6 yolu kopuk olabiliyor. Tarayıcılar bu durumu
  /// "Happy Eyeballs" ile saniyeler içinde aşıyor; Dart'ın HttpClient'ı ise
  /// çözümlenen ilk adrese bağlanmayı deneyip zaman aşımına kadar bekliyor.
  /// Sonuç, kullanıcının ekranında "internet bağlantısı gerekli" olarak
  /// görünüyordu — oysa telefonun interneti çalışıyordu.
  ///
  /// IPv4 çözümlemesi başarısız olursa varsayılan davranışa dönülür; bu
  /// yüzden yalnızca IPv6 olan bir ağda da uygulama çalışmaya devam eder.
  static HttpClient _createHttpClient() {
    final client = HttpClient();

    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      final host = proxyHost ?? uri.host;
      final port = proxyPort ?? uri.port;

      try {
        final addresses = await InternetAddress.lookup(
          host,
          type: InternetAddressType.IPv4,
        );
        if (addresses.isNotEmpty) {
          return Socket.startConnect(addresses.first, port);
        }
      } on Object {
        // Çözümleme yapılamadı — aşağıdaki varsayılan yola düşülür.
      }

      return Socket.startConnect(host, port);
    };

    return client;
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
