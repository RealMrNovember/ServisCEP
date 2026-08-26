import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/money.dart';

/// Ödemenin nereden geldiği.
enum PaymentKind {
  /// Uygulama içinden kartla.
  card,

  /// Havale/EFT — kullanıcı bildirdi, yönetim onayladı.
  transfer,
}

/// Ödemenin durumu.
///
/// Kart ve havale için AYNI kelimeler kullanılır; kullanıcı iki ayrı
/// sözlük öğrenmek zorunda değil. Çeviri sunucuda yapılıyor.
enum PaymentState { pending, paid, failed }

/// Abonelik ödeme geçmişindeki tek kayıt.
class PaymentHistoryItem {
  const PaymentHistoryItem({
    required this.id,
    required this.kind,
    required this.state,
    required this.createdAt,
    required this.amountMinor,
    this.paidAt,
    this.planName,
    this.duration,
    this.reference,
    this.note,
  });

  final String id;
  final PaymentKind kind;
  final PaymentState state;
  final DateTime createdAt;
  final DateTime? paidAt;

  /// Havale bildiriminde kullanıcının beyan ettiği tutar boş olabilir.
  final int? amountMinor;

  final String? planName;

  /// MONTHLY / YEARLY. Havalede onaylanana kadar boş.
  final String? duration;

  /// Kartta sağlayıcı sipariş numarası — destekle konuşurken gerekiyor.
  final String? reference;

  /// Başarısız/reddedilmiş kayıtta sebep. "Reddedildi" deyip susmak,
  /// kullanıcıyı ne yapacağını bilmeden bırakıyor.
  final String? note;

  factory PaymentHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime? tarih(Object? value) =>
        value is String ? DateTime.tryParse(value)?.toLocal() : null;

    return PaymentHistoryItem(
      id: json['id'] as String,
      kind: json['kind'] == 'card' ? PaymentKind.card : PaymentKind.transfer,
      state: switch (json['status']) {
        'PAID' => PaymentState.paid,
        'FAILED' => PaymentState.failed,
        _ => PaymentState.pending,
      },
      createdAt: tarih(json['created_at']) ?? DateTime.now(),
      paidAt: tarih(json['paid_at']),
      amountMinor: (json['amount_minor'] as num?)?.toInt(),
      planName: json['plan_name'] as String?,
      duration: json['duration'] as String?,
      reference: json['reference'] as String?,
      note: json['note'] as String?,
    );
  }

  String get durationLabel => switch (duration) {
    'YEARLY' => 'Yıllık',
    'MONTHLY' => 'Aylık',
    _ => '',
  };

  String get kindLabel =>
      kind == PaymentKind.card ? 'Kartla ödeme' : 'Havale / EFT';

  String get stateLabel => switch (state) {
    PaymentState.paid => 'Ödendi',
    PaymentState.failed => 'Başarısız',
    PaymentState.pending =>
      kind == PaymentKind.transfer
          // Havalede "bekliyor" demek onay bekliyor demek; kullanıcı
          // neyi beklediğini bilmeli.
          ? 'Onay bekliyor'
          : 'Bekliyor',
  };

  /// Kullanıcının TAKİP ettiği kayıt mı, yoksa geçmiş mi.
  ///
  /// Bekleyen bir talep eylem bekler ("onaylandı mı?"); geçmiş kayıt
  /// yalnızca referanstır. İkisini aynı listede karıştırmak, kullanıcıyı
  /// kendi talebini aramaya zorluyordu.
  bool get isOpen => state == PaymentState.pending;

  String get amountLabel => amountMinor == null
      ? '—'
      : Money.formatMinor(amountMinor!, currency: Currency.try_);
}

/// Ödeme geçmişi — kart ve havale bir arada, sunucudan hazır gelir.
final paymentHistoryProvider = FutureProvider<List<PaymentHistoryItem>>((
  ref,
) async {
  final client = ref.watch(apiClientProvider);
  try {
    final response = await client.dio.get('/subscription/history');
    final data =
        (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((e) => PaymentHistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    client.throwApiException(e);
  }
});
