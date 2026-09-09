import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../shared/tc_icon.dart';
import 'data/subscription_models.dart';
import 'data/subscription_repository.dart';
import 'subscription_screen.dart';

/// Aboneliği dolmuş hesapta YENİ KAYIT oluşturmayı engelleyen kapı.
///
/// Kapı neden burada, sunucuda değil: sunucudaki abonelik kapısı veri
/// uçlarını 402 ile kesiyordu ve bu, ödemesi geciken müşterinin
/// YEDEKLEMESİNİ de durduruyordu. Kayıtlar telefonda kalıyor, sunucuya
/// hiç ulaşmıyordu — canlıda iki hafta boyunca yaşandı. Telefon
/// kaybolsa veri de kaybolacaktı.
///
/// Ayrım şu: birikeni göndermek serbest, YENİSİNİ oluşturmak değil.
/// Yedekleme hiçbir koşulda durmaz; ücretlendirme kullanıcının önüne
/// yeni kayıt açmak istediğinde çıkar.
///
/// Kullanım — oluşturma akışını başlatan her yerde:
/// ```dart
/// if (!await abonelikIzinVerir(context, ref)) return;
/// ```
Future<bool> abonelikIzinVerir(BuildContext context, WidgetRef ref) async {
  final durum = ref.read(subscriptionStatusProvider).valueOrNull;

  // Durum BİLİNMİYORSA geçit açık.
  //
  // Çevrimdışı bir kullanıcının önüne "aboneliğin doldu" duvarı
  // çıkarmak, tam da uygulamanın var oluş sebebine aykırı: sahada
  // internet yokken çalışabilmek. Yanlışlıkla birkaç kayıt fazladan
  // girilmesi, çalışan bir kullanıcıyı sahada durdurmaktan iyidir.
  if (durum == null || durum.hasActiveSubscription) return true;

  if (!context.mounted) return false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AbonelikSayfasi(durum: durum),
  );

  return false;
}

/// Abonelik uygunsa [git]'i çalıştırır, değilse ödeme akışını açar.
///
/// Kapı ÇAĞRI NOKTASINDA duruyor, form ekranının içinde değil: ekranı
/// açıp hemen kapatmak kullanıcıya formun bir anlığına görünüp
/// kaybolduğu bir sıçrama yaşatıyor. Burada hiç açılmıyor.
///
/// Uygulandığı yerler: yeni müşteri, yeni iş, yeni teklif, yeni
/// proforma, yeni servis talebi, yeni ürün. Yeni bir oluşturma akışı
/// eklendiğinde buraya da eklenmeli.
Future<void> abonelikliGit(
  BuildContext context,
  WidgetRef ref,
  VoidCallback git,
) async {
  if (await abonelikIzinVerir(context, ref)) git();
}

class _AbonelikSayfasi extends StatelessWidget {
  const _AbonelikSayfasi({required this.durum});

  final SubscriptionStatus durum;

  Future<void> _whatsapp() async {
    final numara = durum.supportWhatsapp;
    if (numara == null || numara.isEmpty) return;

    final mesaj = Uri.encodeComponent(
      'Merhaba, TeknikCEP aboneliğim hakkında yardım almak istiyorum.',
    );
    await launchUrl(
      Uri.parse('https://wa.me/$numara?text=$mesaj'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TcIcon(TcIcons.lock, size: 20, color: palet.warningText),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    durum.isTrial
                        ? 'Deneme süren doldu'
                        : 'Abonelik süren doldu',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Kullanıcının ilk korkusu verisidir. Cevap ilk cümlede.
            Text(
              'Kayıtların yerinde duruyor ve sunucuya gönderilmeye devam '
              'ediyor — hiçbir şey kaybolmadı. Yalnızca yeni kayıt '
              'oluşturmak için aboneliğini yenilemen gerekiyor.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palet.textMuted),
            ),

            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen(),
                    ),
                  );
                },
                child: const Text('Paket seç ve öde'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Havale yapmış ama onay bekleyen kullanıcı için ayrı yol:
            // "öde" düğmesi ona hiçbir şey söylemiyor, parayı zaten
            // göndermiş.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen(),
                    ),
                  );
                },
                child: const Text('Ödemeyi yaptım, bildirmek istiyorum'),
              ),
            ),

            if (durum.destekHattiVar) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _whatsapp,
                  icon: const TcIcon(TcIcons.phone, size: 18),
                  label: const Text('WhatsApp ile bize ulaş'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
