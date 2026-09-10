import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/subscription_repository.dart';

/// Sunucuya hiç ulaşılamadığında kullanılacak destek numarası.
///
/// Backend'deki `SubscriptionController::VARSAYILAN_WHATSAPP` ile aynı
/// olmalı. Burada bir kopyasının durmasının sebebi şu: destek hattına EN
/// ÇOK ihtiyaç duyulan an, hiçbir şeyin çalışmadığı andır — giriş
/// yapılamıyor, senkron dönmüyor, sunucu cevap vermiyor. O anda "destek
/// numarası yüklenemedi" demek, kullanıcıyı tam da yardım isteyeceği
/// yerde yalnız bırakmak olurdu.
const varsayilanDestekWhatsapp = '905354895050';

/// Gösterilecek destek numarası — yoksa null (düğme hiç çıkmaz).
///
/// Öncelik sunucudadır: numara panelden değiştirilebilsin diye.
/// Yönetici numarayı BİLEREK boşaltmışsa (`destekHattiVar == false`)
/// varsayılana düşülmez; bu, "şu an destek hattı yok" demenin yoludur ve
/// çalışmayan bir düğme göstermekten iyidir.
final destekWhatsappProvider = Provider<String?>((ref) {
  final durum = ref.watch(subscriptionStatusProvider).valueOrNull;

  if (durum != null) {
    // Sunucu konuştu: kararı o veriyor.
    return durum.destekHattiVar ? durum.supportWhatsapp!.trim() : null;
  }

  // Henüz yüklenmedi ya da hiç ulaşılamadı.
  return varsayilanDestekWhatsapp;
});

/// wa.me bağlantısı.
///
/// Numaradan rakam dışındaki her şey atılıyor: panele "+90 535 489 50 50"
/// gibi okunaklı bir biçimde girilmiş olabilir, wa.me ise yalnızca
/// rakam kabul ediyor ve aksi hâlde sessizce boş bir sohbet açıyor.
Uri destekWhatsappUri(String numara, String mesaj) {
  final rakamlar = numara.replaceAll(RegExp(r'[^0-9]'), '');
  return Uri.parse('https://wa.me/$rakamlar?text=${Uri.encodeComponent(mesaj)}');
}
