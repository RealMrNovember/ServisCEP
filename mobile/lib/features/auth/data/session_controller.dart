import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/push_service.dart';
import 'auth_repository.dart';

/// Uygulama genelinde geçerli oturum durumu.
///
/// `AsyncValue<AuthSession?>`:
/// - loading: henüz secure storage kontrol edilmedi
/// - data(null): oturum yok (giriş/kayıt ekranına yönlendirilmeli)
/// - data(session): giriş yapılmış
class SessionController extends StateNotifier<AsyncValue<AuthSession?>> {
  SessionController(this._repository, {this.onBeforeLogout})
    : super(const AsyncValue.loading()) {
    _restore();
  }

  final AuthRepository _repository;

  /// Oturum kapanmadan ÖNCE, jeton hâlâ geçerliyken çalışması gereken iş
  /// (bildirim kaydının silinmesi). Bkz. [logout].
  final Future<void> Function()? onBeforeLogout;

  Future<void> _restore() async {
    try {
      final session = await _repository.restoreSession();
      state = AsyncValue.data(session);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> register({
    required String companyName,
    required List<String> businessTypes,
    required String ownerFullName,
    required String email,
    required String? phone,
    required String password,
  }) async {
    final session = await _repository.register(
      companyName: companyName,
      businessTypes: businessTypes,
      ownerFullName: ownerFullName,
      email: email,
      phone: phone,
      password: password,
    );
    state = AsyncValue.data(session);
  }

  Future<void> login({required String email, required String password}) async {
    final session = await _repository.login(email: email, password: password);
    state = AsyncValue.data(session);
  }

  /// Google ile devam et — hesap backend'de zaten var olmalı. Yoksa
  /// `AuthException` fırlatır, çağıran taraf onboarding'e yönlendirmelidir.
  Future<void> continueWithGoogle(
    String idToken, {
    required String email,
  }) async {
    final session = await _repository.loginWithGoogle(idToken, email: email);
    state = AsyncValue.data(session);
  }

  Future<void> registerWithGoogle({
    required String idToken,
    required String companyName,
    required List<String> businessTypes,
    required String email,
    String? phone,
  }) async {
    final session = await _repository.registerWithGoogle(
      idToken: idToken,
      companyName: companyName,
      businessTypes: businessTypes,
      email: email,
      phone: phone,
    );
    state = AsyncValue.data(session);
  }

  /// Çıkış.
  ///
  /// Bildirim kaydı EN BAŞTA kaldırılır: silme isteği jetona ihtiyaç
  /// duyuyor. Önceden bu iş, oturum kapandıktan SONRA bir dinleyici
  /// üzerinden yapılıyordu ve elinde jeton olmadığı için hep 401 alıyordu.
  /// Sonuç, çıkış yapılan cihazın sunucuda kayıtlı kalması ve o hesabın
  /// bildirimlerini almaya devam etmesiydi.
  Future<void> logout() async {
    await onBeforeLogout?.call();
    await _repository.logout();
    state = const AsyncValue.data(null);
  }
}

final sessionControllerProvider =
    StateNotifierProvider<SessionController, AsyncValue<AuthSession?>>((ref) {
      return SessionController(
        ref.watch(authRepositoryProvider),
        // `read` bilinçli: push servisi oturumu izlemiyor, yalnızca çıkış
        // anında bir kez gerekiyor. `watch` kullanmak gereksiz yeniden
        // oluşturmalara yol açardı.
        onBeforeLogout: () => ref.read(pushServiceProvider).unregister(),
      );
    });
