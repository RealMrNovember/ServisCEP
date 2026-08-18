import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthResult {
  const GoogleAuthResult({required this.email, required this.displayName});
  final String email;
  final String displayName;
}

/// Google Sign-In sarmalayıcısı — bkz. docs/09 § Kimlik Doğrulama
/// Yöntemleri.
///
/// NOT: Backend (Phase 3) henüz derinleşmediği için Google kimliği yalnızca
/// e-posta/ad bilgisini almak için kullanılır; asıl hesap yerel veritabanında
/// oluşturulur/eşleştirilir (bkz. AuthRepository.registerWithGoogle /
/// loginVerifiedEmail). Backend hazır olduğunda burada dönen idToken sunucuya
/// gönderilip doğrulanacak şekilde genişletilecektir.
class GoogleAuthService {
  final _googleSignIn = GoogleSignIn(scopes: const ['email', 'profile']);

  Future<GoogleAuthResult?> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null; // kullanıcı iptal etti
    return GoogleAuthResult(email: account.email, displayName: account.displayName ?? account.email);
  }

  Future<void> signOut() => _googleSignIn.signOut();
}
