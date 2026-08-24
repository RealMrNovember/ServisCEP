import 'package:flutter/services.dart';

/// Rehberden seçilen kişinin form doldurmaya yetecek kadarı.
class PickedContact {
  const PickedContact({required this.name, required this.phone});

  final String? name;
  final String? phone;
}

/// Sistem kişi seçicisi köprüsü — bkz. android MainActivity.kt.
///
/// READ_CONTACTS izni İSTENMEZ; sistemin seçicisi açılır, kullanıcı tek
/// kişiyi kendisi seçer. Seçilen veri yalnızca formu doldurmak için
/// kullanılır, hiçbir yere kaydedilmez/senkronlanmaz.
class ContactPicker {
  const ContactPicker();

  static const _channel = MethodChannel(
    'com.cicibyte.serviscep/contact_picker',
  );

  /// Kullanıcı vazgeçerse `null` döner. Rehber uygulaması yoksa veya
  /// okuma başarısızsa [ContactPickerException] fırlatır.
  Future<PickedContact?> pick() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'pickContact',
      );
      if (result == null) return null;
      return PickedContact(
        name: result['name'] as String?,
        phone: result['phone'] as String?,
      );
    } on PlatformException catch (e) {
      throw ContactPickerException(e.message ?? 'Rehber açılamadı.');
    } on MissingPluginException {
      // iOS/desktop veya köprünün olmadığı bir yapı — özellik sessizce
      // kapalı davranır, çağıran taraf butonu gizler.
      return null;
    }
  }
}

class ContactPickerException implements Exception {
  ContactPickerException(this.message);
  final String message;

  @override
  String toString() => message;
}
