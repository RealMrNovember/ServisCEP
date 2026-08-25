import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/core/network/api_client.dart';

import '../../support/fake_token_store.dart';

/// Ağ katmanının kurulumu.
///
/// NOT — burada "soket katmanı özelleştirilmemiş olmalı" diye bir koruma
/// denendi ve KALDIRILDI: Dio'nun mobildeki varsayılan adaptörü zaten
/// `IOHttpClientAdapter`, dolayısıyla test özelleştirmeyi varsayılandan
/// ayırt edemiyordu. Korumadığı bir şeyi koruyormuş gibi duran bir test,
/// hiç olmamasından kötüdür.
///
/// Bu arıza sınıfı birim testleriyle GÖRÜNMEZ: testlerde gerçek soket
/// açılmıyor. `HttpClient.connectionFactory` ile IPv4'ü tercih eden bir
/// katman eklendiğinde 53 test yeşil kaldı, sürüm yayınlandı ve
/// kullanıcılar 11 saat sunucuya ulaşamadı — yakalayan şey sunucu
/// logları oldu.
///
/// Gerçek koruma bir kural: ağ katmanına dokunan değişiklik önce fiziksel
/// cihazda doğrulanır. Gerekçesi `ApiClient` sınıf notunda duruyor.
void main() {
  test('temel ayarlar beklenen değerlerde', () {
    final client = ApiClient(FakeTokenStore());

    expect(client.dio.options.baseUrl, isNotEmpty);
    expect(client.dio.options.headers['Accept'], 'application/json');
    // Google doğrulaması sunucuya ek bir tur attırıyor; kısa zaman aşımı
    // kullanıcıya "internet yok" gibi görünüyordu.
    expect(client.dio.options.connectTimeout, const Duration(seconds: 15));
    expect(client.dio.options.receiveTimeout, const Duration(seconds: 45));
  });

  test('token varsa Authorization başlığı eklenir', () async {
    final client = ApiClient(FakeTokenStore(initialToken: 'jeton'));
    final interceptor = client.dio.interceptors
        .whereType<InterceptorsWrapper>()
        .first;

    final options = RequestOptions(path: '/test');
    final handler = _YakalayanHandler();
    interceptor.onRequest(options, handler);
    await handler.tamamlandi.future;

    expect(options.headers['Authorization'], 'Bearer jeton');
  });
}

/// `handler.next` çağrısını yakalayıp bekleyebilmek için.
class _YakalayanHandler extends RequestInterceptorHandler {
  final tamamlandi = Completer<void>();

  @override
  void next(RequestOptions requestOptions) {
    if (!tamamlandi.isCompleted) tamamlandi.complete();
  }
}
