import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/play_update_service.dart';
import 'theme.dart';

/// Ana navigasyon iskeleti — bkz. docs/06 § Mobil Navigasyon:
/// Ana Sayfa | İşler | Müşteriler | Belgeler | Daha Fazla.
///
/// Kayan (floating), koyu ve marka renkleriyle uyumlu özel bir alt gezinme
/// çubuğu kullanılır — standart [NavigationBar] beş etiketi eşit genişliğe
/// sığdırmaya çalışırken küçük ekranlarda/daha büyük yazı tipi ölçeğinde
/// taşabiliyordu. Etiketler [FittedBox] ile daralan alana göre otomatik
/// küçültülür; bu nedenle hiçbir cihaz genişliğinde taşma oluşmaz.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (icon: Icons.home_rounded, label: 'Ana Sayfa'),
    (icon: Icons.work_rounded, label: 'İşler'),
    (icon: Icons.people_rounded, label: 'Müşteriler'),
    (icon: Icons.folder_rounded, label: 'Belgeler'),
    (icon: Icons.more_horiz_rounded, label: 'Daha Fazla'),
  ];

  /// Alt çubuktaki sekme davranışı.
  ///
  /// Aktif sekmeye TEKRAR basıldığında kullanıcı o sekmenin köküne
  /// dönmeyi bekler. `goBranch(initialLocation: true)` yalnızca GoRouter'ın
  /// bildiği rotaları sıfırlar; "Daha Fazla" altındaki ekranlar
  /// (Abonelik, Personel, Şirket ayarları, İş türleri, Bildirimler,
  /// Takvim, Finans, Stok) ise `Navigator.push` ile açılıyor ve bu yığın
  /// GoRouter'ın durumunda görünmüyor. Bu yüzden önce sekmenin KENDİ
  /// navigator'ında açık bir ekran var mı diye bakılır; varsa köke
  /// dönülür — aksi halde tekrar basmak hiçbir şey yapmıyordu.
  void _onSelect(int index) {
    final isReselect = index == navigationShell.currentIndex;

    if (isReselect) {
      final navigator =
          navigationShell.route.branches[index].navigatorKey.currentState;
      if (navigator != null && navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
        return;
      }
    }

    navigationShell.goBranch(index, initialLocation: isReselect);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playUpdateReady = ref.watch(playUpdateReadyProvider);

    return Scaffold(
      body: Column(
        children: [
          if (playUpdateReady) const _PlayUpdateReadyBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: navigationShell.currentIndex,
        destinations: _destinations,
        onSelect: (index) => _onSelect(index),
      ),
    );
  }
}

/// Play Store üzerinden indirilen bir güncelleme kurulum için hazır
/// olduğunda gösterilir — bkz. play_update_service.dart. GitHub tabanlı
/// [UpdateBanner]'ın aksine burada indirme YOK, yalnızca "yeniden başlat"
/// tetiklenir; indirme zaten Play tarafından sessizce tamamlanmıştır.
class _PlayUpdateReadyBanner extends StatelessWidget {
  const _PlayUpdateReadyBanner();

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: const Text('Güncelleme indirildi. Uygulamayı yeniden başlatmak için devam et.'),
      leading: const Icon(Icons.system_update_alt_rounded),
      actions: [
        TextButton(
          onPressed: () => playUpdateService.completeUpdate(),
          child: const Text('YENİDEN BAŞLAT'),
        ),
      ],
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.currentIndex, required this.destinations, required this.onSelect});

  final int currentIndex;
  final List<({IconData icon, String label})> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? bottomInset + 8 : 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.darkBg,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(color: AppColors.darkBg.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10)),
          ],
        ),
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: destinations[i].icon,
                    label: destinations[i].label,
                    selected: i == currentIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : Colors.white.withValues(alpha: 0.5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: selected ? AppColors.accent : fg),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
