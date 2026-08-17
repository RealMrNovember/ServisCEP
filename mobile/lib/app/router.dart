import 'package:go_router/go_router.dart';

import '../features/dashboard/dashboard_screen.dart';

/// Uygulama navigasyonu. Bkz. docs/06 § Mobil Navigasyon.
///
/// Şu an tek route (Ana Sayfa/Dashboard) tanımlıdır. İşler, Müşteriler,
/// Belgeler, Daha Fazla sekmeleri ilgili özellik fazlarında eklenecektir.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
  ],
);
