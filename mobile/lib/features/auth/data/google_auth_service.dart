import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthResult {
  const GoogleAuthResult({
    required this.email,
    required this.displayName,
    required this.idToken,
  });
  final String email;
  final String displayName;
  final String idToken;
}

class GoogleSignInException implements Exception {
  GoogleSignInException(this.message);
  final String message;
}

/// Google Sign-In sarmalayıcısı — bkz. docs/09 § Kimlik Doğrulama
/// Yöntemleri, ROADMAP.md § B10.
///
/// `idToken`, backend'in `POST /auth/google/login|register` uçlarına
/// gönderilip Socialite ile doğrulanır (bkz. AuthRepository) — Google
/// kimliği artık gerçekten sunucudaki hesaba bağlanır, yerelde sessizce
/// eşleştirilmez.
class GoogleAuthService {
  // serverClientId = "Web application" tipi OAuth client — backend'deki
  // GOOGLE_CLIENT_ID ile AYNI değer olmalı (Socialite'in aud kontrolü
  // buna göre geçer/kalır, bkz. AuthService::verifyGoogleToken).
  final _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId:
        '1043015237090-4nj92cgobk1rfbormmmlpi2uj8g9bkhk.apps.googleusercontent.com',
  );

  Future<GoogleAuthResult?> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null; // kullanıcı iptal etti

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw GoogleSignInException(
        'Google kimlik doğrulaması tamamlanamadı (idToken alınamadı).',
      );
    }

    return GoogleAuthResult(
      email: account.email,
      displayName: account.displayName ?? account.email,
      idToken: idToken,
    );
  }

  Future<void> signOut() => _googleSignIn.signOut();
}
