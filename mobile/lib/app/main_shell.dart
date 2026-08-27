import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/play_update_service.dart';
import '../core/services/update_prompt.dart';
import '../shared/app_bottom_nav.dart';
import '../shared/sync_indicators.dart';
import '../shared/tc_icon.dart';

/// Ana navigasyon iskeleti — bkz. docs/06 § Mobil Navigasyon:
/// Ana Sayfa | İşler | Müşteriler | Belgeler | Menü.
///
/// Alt çubuk için standart [NavigationBar] KULLANILMAZ: beş etiketi eşit
/// genişliğe sığdırmaya çalışırken küçük ekranlarda ve büyük yazı tipi
/// ölçeğinde taşıyordu. Yerine [AppBottomNav] var.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Son sekmenin etiketi "Daha Fazla" değil "Menü".
  ///
  /// Beş sekme dar ekranda yan yana durunca uzun etiketler birbirine
  /// değiyordu; "Daha Fazla" çubuğun sağ kenarına yapışıyordu. "Menü"
  /// hem kısa hem daha doğru — orası gerçekten bir menü.
  static const _destinations = [
    AppNavDestination(icon: TcIcons.home, label: 'Ana Sayfa'),
    AppNavDestination(icon: TcIcons.briefcase, label: 'İşler'),
    AppNavDestination(icon: TcIcons.users, label: 'Müşteriler'),
    AppNavDestination(icon: TcIcons.file, label: 'Belgeler'),
    AppNavDestination(icon: TcIcons.grid, label: 'Menü'),
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

    // Güncelleme hatırlatması uygulama her açıldığında bir kez sorulur —
    // kullanıcılar güncellemenin geldiğini fark etmiyordu. Zorunlu değil:
    // "Sonra" denip çalışmaya devam edilebilir (bkz. UpdatePromptGate).
    return UpdatePromptGate(
      child: Scaffold(
        // Kabuğun Scaffold'unda AppBar YOK, bu yüzden gövde ekranın en
        // tepesinden başlıyor ve şeritler durum çubuğunun ALTINDA kalıyordu
        // (metin saatin ve pil simgesinin arkasına düşüyordu).
        //
        // SafeArea üst dolguyu burada tüketiyor; sekmelerin kendi AppBar'ları
        // da aynı dolguyu ikinci kez eklemiyor. Şerit görünmediğinde sonuç
        // aynı kalıyor: durum çubuğu alanı zaten AppBar ile aynı renk olan
        // ekran zeminiyle doluyor.
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (playUpdateReady) const _PlayUpdateReadyBanner(),
              // Çevrimdışı / eşitleme şeridi — bkz. tasarım sistemi § 6.1.
              //
              // Tasarım şeridi "üst çubuğun hemen altına" koyuyor; burada üst
              // çubuğun ÜSTÜNDE duruyor. Sebep: her sekmenin ve her detay
              // ekranının kendi AppBar'ı var, şeridi 42 ekrana tek tek
              // eklemek gerekirdi. Kabuğa konunca sekmelerde ve onların
              // üstüne push edilen ekranlarda kendiliğinden görünüyor.
              // Kuralın asıl amacı korunuyor: hiçbir şeyin üstüne binmiyor,
              // içeriği aşağı itiyor.
              const SyncBanner(),
              Expanded(child: navigationShell),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: navigationShell.currentIndex,
          destinations: _destinations,
          onSelect: (index) => _onSelect(index),
        ),
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
      content: const Text(
        'Güncelleme indirildi. Uygulamayı yeniden başlatmak için devam et.',
      ),
      leading: const TcIcon(TcIcons.download),
      actions: [
        TextButton(
          onPressed: () => playUpdateService.completeUpdate(),
          child: const Text('YENİDEN BAŞLAT'),
        ),
      ],
    );
  }
}
