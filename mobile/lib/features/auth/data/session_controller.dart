import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

/// Uygulama genelinde geçerli oturum durumu.
///
/// `AsyncValue<AuthSession?>`:
/// - loading: henüz secure storage kontrol edilmedi
/// - data(null): oturum yok (giriş/kayıt ekranına yönlendirilmeli)
/// - data(session): giriş yapılmış
class SessionController extends StateNotifier<AsyncValue<AuthSession?>> {
  SessionController(this._repository) : super(const AsyncValue.loading()) {
    _restore();
  }

  final AuthRepository _repository;

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

  /// Google ile doğrulanmış bir e-posta için mevcut hesaba giriş yapar.
  /// Hesap yoksa `AuthException` fırlatır — çağıran taraf bunu yakalayıp
  /// kullanıcıyı kayıt akışına yönlendirmelidir.
  Future<void> loginWithVerifiedGoogleEmail(String email) async {
    final session = await _repository.loginVerifiedEmail(email);
    state = AsyncValue.data(session);
  }

  Future<void> registerWithGoogle({
    required String companyName,
    required List<String> businessTypes,
    required String ownerFullName,
    required String email,
  }) async {
    final session = await _repository.registerWithGoogle(
      companyName: companyName,
      businessTypes: businessTypes,
      ownerFullName: ownerFullName,
      email: email,
    );
    state = AsyncValue.data(session);
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncValue.data(null);
  }
}

final sessionControllerProvider =
    StateNotifierProvider<SessionController, AsyncValue<AuthSession?>>((ref) {
      return SessionController(ref.watch(authRepositoryProvider));
    });
