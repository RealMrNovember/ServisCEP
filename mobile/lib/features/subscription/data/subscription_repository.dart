import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'subscription_models.dart';

/// Abonelik uçları — çevrimiçi çalışır (outbox'a girmez): abonelik durumu
/// ve ödeme bildirimi, senkron motorunun offline garantilerine ihtiyaç
/// duymayan, düşük frekanslı işlemlerdir.
class SubscriptionRepository {
  SubscriptionRepository(this._client);

  final ApiClient _client;
  Dio get _dio => _client.dio;

  Future<SubscriptionStatus> fetchStatus() async {
    try {
      final response = await _dio.get('/subscription');
      return SubscriptionStatus.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  Future<List<PlanInfo>> fetchPlans() async {
    try {
      final response = await _dio.get('/plans');
      final data =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      return data
          .map((p) => PlanInfo.fromJson(p as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  Future<List<PaymentRequestInfo>> fetchPaymentRequests() async {
    try {
      final response = await _dio.get('/subscription/payment-requests');
      final data =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      return data
          .map((r) => PaymentRequestInfo.fromJson(r as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  Future<void> submitPaymentRequest({
    required String planId,
    required String billingPeriod,
    int? claimedAmountMinor,
    String? customerNote,
  }) async {
    try {
      await _dio.post(
        '/subscription/payment-requests',
        data: {
          'plan_id': planId,
          'billing_period': billingPeriod,
          'claimed_amount_minor': claimedAmountMinor,
          'customer_note': customerNote,
        },
      );
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(apiClientProvider));
});

/// Dashboard banner'ı ve Abonelik ekranı aynı durumu paylaşır — ekran
/// pull-to-refresh yaptığında banner da tazelenir.
final subscriptionStatusProvider = FutureProvider<SubscriptionStatus>((ref) {
  return ref.watch(subscriptionRepositoryProvider).fetchStatus();
});

final plansProvider = FutureProvider<List<PlanInfo>>((ref) {
  return ref.watch(subscriptionRepositoryProvider).fetchPlans();
});

final paymentRequestsProvider = FutureProvider<List<PaymentRequestInfo>>((
  ref,
) {
  return ref.watch(subscriptionRepositoryProvider).fetchPaymentRequests();
});
