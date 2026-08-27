import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Geri bildirim türü.
enum FeedbackType {
  oneri('ONERI', 'Öneri'),
  hata('HATA', 'Bir sorun'),
  soru('SORU', 'Soru'),
  diger('DIGER', 'Diğer');

  const FeedbackType(this.kod, this.etiket);

  final String kod;
  final String etiket;
}

/// Gönderilmiş bir geri bildirim ve varsa yanıtı.
class FeedbackItem {
  const FeedbackItem({
    required this.id,
    required this.type,
    required this.message,
    required this.statusLabel,
    required this.createdAt,
    this.reply,
    this.repliedAt,
  });

  final String id;
  final String type;
  final String message;

  /// Durum metni SUNUCUDAN geliyor; istemci ayrı bir sözlük tutmuyor.
  /// İki yerde tutulan bir sözlük er ya da geç birbirinden sapar.
  final String statusLabel;

  final DateTime createdAt;

  /// Yöneticinin yanıtı. Bildirim kaybolur, bu kayıt kalır.
  final String? reply;
  final DateTime? repliedAt;

  bool get yanitlandi => (reply ?? '').trim().isNotEmpty;

  String get typeLabel => switch (type) {
    'ONERI' => 'Öneri',
    'HATA' => 'Bir sorun',
    'SORU' => 'Soru',
    _ => 'Geri bildirim',
  };

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    DateTime? tarih(Object? v) =>
        v is String ? DateTime.tryParse(v)?.toLocal() : null;

    return FeedbackItem(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'DIGER',
      message: json['message'] as String? ?? '',
      statusLabel: json['status_label'] as String? ?? '',
      createdAt: tarih(json['created_at']) ?? DateTime.now(),
      reply: json['reply'] as String?,
      repliedAt: tarih(json['replied_at']),
    );
  }
}

class FeedbackRepository {
  FeedbackRepository(this._client);

  final ApiClient _client;

  /// Geri bildirimi gönderir.
  ///
  /// ÇEVRİMDIŞI KUYRUĞA ALINMIYOR — bilinçli. Kuyruğa alınan bir mesaj
  /// kullanıcıya "gönderildi" der ama günler sonra gidebilir; o sırada
  /// yazdığı sorun çoktan değişmiş olur. Bunun yerine bağlantı yoksa
  /// açıkça söylenir ve kullanıcı yeniden dener.
  Future<void> gonder({
    required FeedbackType type,
    required String message,
  }) async {
    try {
      await _client.dio.post<void>(
        '/feedback',
        data: {'type': type.kod, 'message': message},
      );
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }

  Future<List<FeedbackItem>> gecmis() async {
    try {
      final yanit = await _client.dio.get('/feedback');
      final veri =
          (yanit.data as Map<String, dynamic>)['data'] as List<dynamic>;
      return veri
          .map((e) => FeedbackItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _client.throwApiException(e);
    }
  }
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  return FeedbackRepository(ref.watch(apiClientProvider));
});

final feedbackHistoryProvider = FutureProvider<List<FeedbackItem>>((ref) {
  return ref.watch(feedbackRepositoryProvider).gecmis();
});
