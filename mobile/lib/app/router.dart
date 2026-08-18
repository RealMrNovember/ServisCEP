import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/database/app_database.dart';
import '../features/auth/data/google_auth_service.dart';
import '../features/auth/data/session_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/customers/customer_detail_screen.dart';
import '../features/customers/customer_form_screen.dart';
import '../features/customers/customers_list_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/documents/documents_screen.dart';
import '../features/jobs/job_detail_screen.dart';
import '../features/jobs/job_form_screen.dart';
import '../features/jobs/jobs_list_screen.dart';
import '../features/more/more_screen.dart';
import 'main_shell.dart';

/// Uygulama navigasyonu — bkz. docs/06 § Mobil Navigasyon.
///
/// Kimlik doğrulama durumu (bkz. features/auth/data/session_controller.dart)
/// `redirect` üzerinden merkezi olarak yönetilir: oturum yoksa giriş/kayıt
/// ekranlarının dışına çıkılamaz, oturum varsa giriş/kayıt ekranlarına
/// dönülemez.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _SessionRefreshListenable(ref),
    redirect: (context, state) {
      final sessionAsync = ref.read(sessionControllerProvider);
      final loc = state.matchedLocation;

      if (sessionAsync.isLoading) {
        return loc == '/' ? null : '/';
      }

      final session = sessionAsync.valueOrNull;
      final isAuthRoute = loc == '/login' || loc == '/onboarding';

      if (session == null) {
        return isAuthRoute ? null : '/login';
      }
      if (isAuthRoute || loc == '/') {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) =>
            OnboardingScreen(googlePrefill: state.extra as GoogleAuthResult?),
      ),

      // Müşteri detay/form ekranları — shell'in üzerine tam ekran açılır.
      GoRoute(
        path: '/customers/new',
        builder: (context, state) => const CustomerFormScreen(),
      ),
      GoRoute(
        path: '/customers/:id',
        builder: (context, state) =>
            CustomerDetailScreen(customerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/customers/:id/edit',
        builder: (context, state) =>
            CustomerFormScreen(existing: state.extra as Customer?),
      ),

      // İş detay/form ekranları
      GoRoute(
        path: '/jobs/new',
        builder: (context, state) => JobFormScreen(
          preselectedCustomerId: state.uri.queryParameters['customerId'],
        ),
      ),
      GoRoute(
        path: '/jobs/:id',
        builder: (context, state) => JobDetailScreen(jobId: state.pathParameters['id']!),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/jobs', builder: (context, state) => const JobsListScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/customers',
                builder: (context, state) => const CustomersListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/documents', builder: (context, state) => const DocumentsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/more', builder: (context, state) => const MoreScreen())],
          ),
        ],
      ),
    ],
  );
});

/// Riverpod oturum durumundaki değişiklikleri GoRouter'ın anlayacağı
/// bir [Listenable]'a köprüler — böylece login/logout sonrası `redirect`
/// otomatik olarak yeniden tetiklenir.
class _SessionRefreshListenable extends ChangeNotifier {
  _SessionRefreshListenable(Ref ref) {
    ref.listen(sessionControllerProvider, (_, _) => notifyListeners());
  }
}
