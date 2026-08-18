import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Ana navigasyon iskeleti — bkz. docs/06 § Mobil Navigasyon:
/// Ana Sayfa | İşler | Müşteriler | Belgeler | Daha Fazla.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Ana Sayfa'),
    (icon: Icons.work_outline_rounded, selectedIcon: Icons.work_rounded, label: 'İşler'),
    (icon: Icons.people_outline_rounded, selectedIcon: Icons.people_rounded, label: 'Müşteriler'),
    (
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder_rounded,
      label: 'Belgeler',
    ),
    (icon: Icons.more_horiz_rounded, selectedIcon: Icons.more_horiz_rounded, label: 'Daha Fazla'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }
}
