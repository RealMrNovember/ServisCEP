import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/sync_api_client.dart';

/// Roller — backend `RolePermissions` ile birebir aynı olmak ZORUNDA.
/// Arayüzdeki gizleme yalnızca deneyim içindir; asıl yaptırım sunucudadır.
const roleLabels = <String, String>{
  'OWNER': 'İşletme Sahibi',
  'ADMIN': 'Yönetici',
  'TECHNICIAN': 'Teknisyen',
  'ACCOUNTING': 'Muhasebe',
  'VIEWER': 'Görüntüleyici',
};

/// Personel eklerken seçilebilecek roller — OWNER buradan atanamaz
/// (sahiplik devri ayrı ve bilinçli bir akış olmalı; backend de reddeder).
const assignableRoles = ['ADMIN', 'TECHNICIAN', 'ACCOUNTING', 'VIEWER'];

const roleDescriptions = <String, String>{
  'ADMIN': 'Finans dahil her şeyi yönetir; personel ve şirket ayarlarına dokunamaz.',
  'TECHNICIAN': 'Müşteri ve işleri yönetir. İşletmenin finansal verilerini GÖREMEZ.',
  'ACCOUNTING': 'Finans, tahsilat, teklif ve cari hesabı yönetir. İş açamaz.',
  'VIEWER': 'Yalnızca görüntüler, hiçbir kayıt oluşturamaz veya değiştiremez.',
};

class Personnel {
  Personnel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.phone,
  });

  factory Personnel.fromJson(Map<String, dynamic> json) => Personnel(
    id: json['id'] as String,
    fullName: json['full_name'] as String,
    email: json['email'] as String,
    role: json['role'] as String? ?? 'VIEWER',
    phone: json['phone'] as String?,
  );

  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? phone;

  bool get isOwner => role == 'OWNER';
  String get roleLabel => roleLabels[role] ?? role;
}

/// Personel yönetimi çevrimiçi çalışır (outbox'a girmez): hesap oluşturma
/// ve yetki değişikliği sunucunun doğrulaması gereken, düşük frekanslı ve
/// güvenlik açısından kritik işlemlerdir — çevrimdışı kuyruklanmamalıdır.
class PersonnelRepository {
  PersonnelRepository(this._api);

  final SyncApiClient _api;

  Future<List<Personnel>> fetchAll() async {
    final raw = await _api.listPersonnel();
    return raw.map(Personnel.fromJson).toList();
  }

  Future<void> create({
    required String fullName,
    required String email,
    required String role,
    required String password,
    String? phone,
  }) {
    return _api.createPersonnel({
      'full_name': fullName,
      'email': email,
      'role': role,
      'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
  }

  Future<void> changeRole(String id, String role) =>
      _api.updatePersonnel(id, {'role': role});

  Future<void> remove(String id) => _api.deletePersonnel(id);
}

final personnelRepositoryProvider = Provider<PersonnelRepository>((ref) {
  return PersonnelRepository(ref.watch(syncApiClientProvider));
});

final personnelListProvider = FutureProvider<List<Personnel>>((ref) {
  return ref.watch(personnelRepositoryProvider).fetchAll();
});
