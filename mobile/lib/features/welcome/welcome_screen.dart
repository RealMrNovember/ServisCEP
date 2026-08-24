import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import 'welcome_controller.dart';

/// İlk açılış karşılama akışı — kullanıcı uygulamaya "bodoslama" girmez:
/// marka kimliğiyle uyumlu (koyu zemin + tek mavi vurgu, bkz. docs/14)
/// 5 kısa tanıtım sayfası, atlanabilir, yalnızca bir kez gösterilir
/// (bkz. WelcomeSeenController).
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomePage {
  const _WelcomePage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

const _pages = [
  _WelcomePage(
    icon: Icons.handyman_rounded,
    title: 'TeknikCEP\'e hoş geldin',
    body:
        'Saha teknik servis işletmeni tek uygulamadan yönet: müşteriler, '
        'işler, belgeler ve finans — hepsi cebinde.',
  ),
  _WelcomePage(
    icon: Icons.assignment_turned_in_rounded,
    title: 'Müşteri ve iş takibi',
    body:
        'Müşteri kayıtları, servis talepleri ve iş emirleri tek yerde. '
        'Talebi tek dokunuşla işe dönüştür, durumunu adım adım izle.',
  ),
  _WelcomePage(
    icon: Icons.description_rounded,
    title: 'Profesyonel belgeler',
    body:
        'Teklif, proforma ve servis formlarını dakikalar içinde oluştur; '
        'fotoğraf ve dijital imza ekle, PDF olarak WhatsApp\'tan paylaş.',
  ),
  _WelcomePage(
    icon: Icons.account_balance_wallet_rounded,
    title: 'Finans ve stok kontrolü',
    body:
        'Gelir-gider, tahsilat ve müşteri cari hesabı her an elinin '
        'altında. Barkod okutarak stok kataloğunu yönet.',
  ),
  _WelcomePage(
    icon: Icons.cloud_sync_rounded,
    title: 'İnternetsiz de çalışır',
    body:
        'Sahada çekim olmasa bile çalışmaya devam et — verilerin bağlantı '
        'gelince güvenle senkronlanır. 14 gün ücretsiz dene, hemen başla.',
  ),
];

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _pages.length - 1;

  Future<void> _finish() async {
    await ref.read(welcomeSeenProvider.notifier).markSeen();
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // Üst şerit: yalnızca "Atla" — son sayfada gizlenir.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: AnimatedOpacity(
                  opacity: _isLast ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: _isLast ? null : _finish,
                    child: const Text(
                      'Atla',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 132,
                          height: 132,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withValues(alpha: 0.12),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Icon(
                            page.icon,
                            size: 60,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15.5,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Nokta göstergesi.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.accent : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _next,
                  child: Text(_isLast ? 'Hadi başlayalım' : 'Devam'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
