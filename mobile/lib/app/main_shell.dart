import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';

/// Ana navigasyon iskeleti — bkz. docs/06 § Mobil Navigasyon:
/// Ana Sayfa | İşler | Müşteriler | Belgeler | Daha Fazla.
///
/// Kayan (floating), koyu ve marka renkleriyle uyumlu özel bir alt gezinme
/// çubuğu kullanılır — standart [NavigationBar] beş etiketi eşit genişliğe
/// sığdırmaya çalışırken küçük ekranlarda/daha büyük yazı tipi ölçeğinde
/// taşabiliyordu. Etiketler [FittedBox] ile daralan alana göre otomatik
/// küçültülür; bu nedenle hiçbir cihaz genişliğinde taşma oluşmaz.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (icon: Icons.home_rounded, label: 'Ana Sayfa'),
    (icon: Icons.work_rounded, label: 'İşler'),
    (icon: Icons.people_rounded, label: 'Müşteriler'),
    (icon: Icons.folder_rounded, label: 'Belgeler'),
    (icon: Icons.more_horiz_rounded, label: 'Daha Fazla'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: navigationShell.currentIndex,
        destinations: _destinations,
        onSelect: (index) =>
            navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
      ),
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
