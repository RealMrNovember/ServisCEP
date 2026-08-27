import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../shared/tc_icon.dart';
import '../../shared/ui.dart';
import '../../shared/wordmark.dart';
import 'welcome_controller.dart';

/// Karşılama — tasarım teslimatı ekran 16.
///
/// Önceden beş sayfalık bir tanıtım turuydu: kullanıcı kayıt olmadan
/// önce dört kez kaydırmak zorundaydı ve çoğu "Atla"ya basıyordu. Tek
/// ekran, üç somut fayda ve iki düğme — anlatılacak şey zaten üç madde.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  static const _faydalar = [
    (
      TcIcons.cloudOff,
      'İnternet yokken de çalışır',
      'Bodrumda kaydet, sinyal gelince kendisi eşitlenir.',
    ),
    (
      TcIcons.file,
      'Teklifi sahada hazırla',
      'PDF teklifi müşteriye anında gönder.',
    ),
    (
      TcIcons.wallet,
      'Cari hesabı takip et',
      'Kim ne ödedi, kim borçlu — tek bakışta.',
    ),
  ];

  Future<void> _bitir(BuildContext context, WidgetRef ref, String hedef) async {
    await ref.read(welcomeSeenProvider.notifier).markSeen();
    if (context.mounted) context.go(hedef);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palet = context.palette;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.xxl,
                  AppSpacing.xxl,
                  AppSpacing.lg,
                ),
                children: [
                  const Wordmark(fontSize: 26),
                  const SizedBox(height: AppSpacing.x3l),
                  Text(
                    'Sahadaki işin\ntek yerden yönetimi',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(height: 1.2),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Müşteri, iş, teklif, tahsilat ve stok. Hepsi cebinde, '
                    'hepsi çevrimdışı çalışır.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palet.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  for (final (ikon, baslik, aciklama) in _faydalar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: AppCard(
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: palet.accent.withValues(alpha: 0.12),
                                borderRadius: AppRadius.field,
                              ),
                              child: Center(
                                child: TcIcon(
                                  ikon,
                                  size: 18,
                                  color: palet.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    baslik,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    aciklama,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: palet.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                0,
                AppSpacing.xxl,
                AppSpacing.xl,
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      // Kayıt ekranına gidiyor: karşılamayı okuyan
                      // kullanıcının henüz hesabı yok.
                      onPressed: () => _bitir(context, ref, '/onboarding'),
                      child: const Text('Hemen Başla'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _bitir(context, ref, '/login'),
                      child: const Text('Hesabım Var, Giriş Yap'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
