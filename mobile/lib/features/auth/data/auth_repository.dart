import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/sync_api_client.dart';
import '../../../core/network/token_store.dart';
import '../../../core/providers/core_providers.dart';

const _sessionUserIdKey = 'session_user_id';
const _sessionCompanyIdKey = 'session_company_id';

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.companyId,
    required this.fullName,
    required this.companyName,
    this.role = 'OWNER',
  });

  final String userId;
  final String companyId;
  final String fullName;
  final String companyName;

  /// OWNER / ADMIN / TECHNICIAN / ACCOUNTING / VIEWER — bkz. backend
  /// RolePermissions. Arayüzde yetkisiz bölümleri gizlemek için kullanılır;
  /// asıl yaptırım her zaman SUNUCUDADIR (istemci gizlemesi güvenlik
  /// değil, kullanıcı deneyimidir).
  final String role;

  bool get isOwner => role == 'OWNER';
  bool get canSeeFinance => role == 'OWNER' || role == 'ADMIN' || role == 'ACCOUNTING';
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
}

/// Kayıt online, giriş offline-capable — bkz. ROADMAP.md § B10 mobil
/// senkron motoru.
///
/// **Kayıt**: internet gerektirir — backend'e kayıt olunur, sunucunun
/// ürettiği `company_id`/`user_id` yerel DB'ye yazılır (ID uyuşmazlığı hiç
/// oluşmaz). Parola ayrıca yerelde tuzlanmış SHA-256 ile saklanır ki
/// sonraki girişler offline çalışabilsin.
///
/// **Giriş**: önce yerel DB denenir (tamamen offline). Yerelde kullanıcı
/// yoksa (yeni bir cihaz) ve bağlantı varsa backend'den giriş yapılıp
/// yerel DB hazırlanır (hydrate). Bir cihazda zaten giriş yapılmış bir
/// hesabın parolası başka bir cihazda değiştirilirse, bu cihazdaki eski
/// yerel hash geçerliliğini korur — parola değişikliğinin cihazlar arası
/// yayılması bu iterasyonun kapsamı dışında.
///
/// **Google ile devam et**: idToken backend'e (`/auth/google/login` veya
/// `/auth/google/register`) gönderilip Socialite ile doğrulanır — artık
/// e-posta/ad yerelde "doğrulanmış sayılıp" sessizce eşleştirilmiyor (bu,
/// yerel veri temizlenince veya yeni bir cihazda kullanıcının var olan
/// hesabına ulaşamayıp zorla yeniden kayıt akışına düşmesine sebep
/// oluyordu — gerçek kullanıcı testinde bulundu, bkz. ROADMAP.md § B10).
class AuthRepository {
  AuthRepository(
    this._db,
    this._storage,
    this._syncApiClient,
    this._tokenStore,
  );

  final AppDatabase _db;
  final FlutterSecureStorage _storage;
  final SyncApiClient _syncApiClient;
  final TokenStore _tokenStore;

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  String _generateSalt() {
    final rand = Random.secure();
    return List.generate(
      16,
      (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<bool> hasAnyCompany() async {
    final company = await _db.select(_db.companies).getSingleOrNull();
    return company != null;
  }

  /// "Google ile devam et" → hesap backend'de ZATEN var olmalı. Yoksa
  /// backend 422 döner, biz bunu `AuthException` olarak fırlatırız —
  /// çağıran taraf (LoginScreen) bunu yakalayıp onboarding'e (Google
  /// bilgileri ön-dolu) yönlendirmelidir.
  Future<AuthSession> loginWithGoogle(
    String idToken, {
    required String email,
  }) async {
    final AuthTokenResult result;
    try {
      result = await _syncApiClient.loginWithGoogle(idToken);
    } on ApiException catch (e) {
      throw AuthException(
        e.statusCode == null ? 'İnternet bağlantısı gerekli.' : e.message,
      );
    }
    return _hydrateAndPersist(
      result,
      email: email,
      passwordHash: 'GOOGLE_AUTH',
    );
  }

  /// Onboarding'in Google akışı — kullanıcı işletme türü/şirket adını
  /// girip gönderdiğinde çağrılır. Hesap zaten varsa backend 422 döner.
  Future<AuthSession> registerWithGoogle({
    required String idToken,
    required String companyName,
    required List<String> businessTypes,
    required String email,
    String? phone,
  }) async {
    final AuthTokenResult result;
    try {
      result = await _syncApiClient.registerWithGoogle(
        idToken: idToken,
        companyName: companyName,
        businessTypes: businessTypes.isEmpty ? null : businessTypes.join(','),
        phone: phone,
      );
    } on ApiException catch (e) {
      throw AuthException(
        e.statusCode == null
            ? 'Hesap oluşturmak için internet bağlantısı gerekli.'
            : e.message,
      );
    }
    return _hydrateAndPersist(
      result,
      email: email,
      passwordHash: 'GOOGLE_AUTH',
      phone: phone,
    );
  }

  /// Backend'in döndüğü company/user'ı yerel DB'ye yazar (yoksa oluşturur,
  /// varsa üzerine yazar — `login`/Google akışlarının hepsinde ortak).
  Future<AuthSession> _hydrateAndPersist(
    AuthTokenResult result, {
    required String email,
    required String passwordHash,
    String? phone,
  }) async {
    await _db
        .into(_db.companies)
        .insertOnConflictUpdate(
          CompaniesCompanion.insert(
            id: result.companyId,
            name: result.companyName,
          ),
        );
    await _db
        .into(_db.users)
        .insertOnConflictUpdate(
          UsersCompanion.insert(
            id: result.userId,
            companyId: result.companyId,
            fullName: result.fullName,
            email: email,
            phone: Value(phone),
            passwordHash: passwordHash,
            role: Value(result.role),
          ),
        );

    await _tokenStore.write(result.token);
    await _persistSession(userId: result.userId, companyId: result.companyId);

    return AuthSession(
      userId: result.userId,
      companyId: result.companyId,
      fullName: result.fullName,
      companyName: result.companyName,
      role: result.role,
    );
  }

  Future<AuthSession> register({
    required String companyName,
    required List<String> businessTypes,
    required String ownerFullName,
    required String email,
    required String? phone,
    required String password,
  }) async {
    final existing = await (_db.select(
      _db.users,
    )..where((u) => u.email.equals(email))).getSingleOrNull();
    if (existing != null) {
      throw AuthException('Bu e-posta ile zaten bir hesap var.');
    }

    final AuthTokenResult result;
    try {
      result = await _syncApiClient.register(
        companyName: companyName,
        businessTypes: businessTypes.isEmpty ? null : businessTypes.join(','),
        fullName: ownerFullName,
        email: email,
        phone: phone,
        password: password,
      );
    } on ApiException catch (e) {
      throw AuthException(
        e.statusCode == null
            ? 'Hesap oluşturmak için internet bağlantısı gerekli.'
            : e.message,
      );
    }

    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);

    await _db
        .into(_db.companies)
        .insert(
          CompaniesCompanion.insert(
            id: result.companyId,
            name: result.companyName,
            businessTypes: Value(businessTypes.join(',')),
          ),
        );

    await _db
        .into(_db.users)
        .insert(
          UsersCompanion.insert(
            id: result.userId,
            companyId: result.companyId,
            fullName: result.fullName,
            email: email,
            phone: Value(phone),
            passwordHash: '$salt\$$hash',
            role: Value(result.role),
          ),
        );

    await _tokenStore.write(result.token);
    await _persistSession(userId: result.userId, companyId: result.companyId);

    return AuthSession(
      userId: result.userId,
      companyId: result.companyId,
      fullName: result.fullName,
      companyName: result.companyName,
      role: result.role,
    );
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final user = await (_db.select(
      _db.users,
    )..where((u) => u.email.equals(email))).getSingleOrNull();

    if (user != null) {
      return _loginLocally(user, password);
    }

    // Bu cihazda hesap yok — internet varsa backend'den giriş dene (ör.
    // hesap başka bir cihazda/web panelden oluşturulmuş, bu ilk giriş).
    final AuthTokenResult result;
    try {
      result = await _syncApiClient.login(email: email, password: password);
    } on ApiException catch (e) {
      throw AuthException(
        e.statusCode == null
            ? 'Bu cihazda hesap bulunamadı, internet bağlantısı gerekli.'
            : 'E-posta veya parola hatalı.',
      );
    }

    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);
    return _hydrateAndPersist(
      result,
      email: email,
      passwordHash: '$salt\$$hash',
    );
  }

  Future<AuthSession> _loginLocally(User user, String password) async {
    final parts = user.passwordHash.split(r'$');
    if (parts.length != 2) {
      throw AuthException(
        'Hesap bilgisi bozuk, lütfen destekle iletişime geçin.',
      );
    }
    final expectedHash = _hashPassword(password, parts[0]);
    if (expectedHash != parts[1]) {
      throw AuthException('E-posta veya parola hatalı.');
    }

    final company = await (_db.select(
      _db.companies,
    )..where((c) => c.id.equals(user.companyId))).getSingle();

    await _persistSession(userId: user.id, companyId: user.companyId);

    return AuthSession(
      userId: user.id,
      companyId: user.companyId,
      fullName: user.fullName,
      companyName: company.name,
      role: user.role,
    );
  }

  Future<void> _persistSession({
    required String userId,
    required String companyId,
  }) async {
    await _storage.write(key: _sessionUserIdKey, value: userId);
    await _storage.write(key: _sessionCompanyIdKey, value: companyId);
  }

  Future<AuthSession?> restoreSession() async {
    final userId = await _storage.read(key: _sessionUserIdKey);
    final companyId = await _storage.read(key: _sessionCompanyIdKey);
    if (userId == null || companyId == null) return null;

    final user = await (_db.select(
      _db.users,
    )..where((u) => u.id.equals(userId))).getSingleOrNull();
    final company = await (_db.select(
      _db.companies,
    )..where((c) => c.id.equals(companyId))).getSingleOrNull();
    if (user == null || company == null) {
      await logout();
      return null;
    }

    return AuthSession(
      userId: user.id,
      companyId: company.id,
      fullName: user.fullName,
      companyName: company.name,
      role: user.role,
    );
  }

  Future<void> logout() async {
    await _storage.delete(key: _sessionUserIdKey);
    await _storage.delete(key: _sessionCompanyIdKey);
    await _tokenStore.clear();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(databaseProvider),
    ref.watch(secureStorageProvider),
    ref.watch(syncApiClientProvider),
    ref.watch(tokenStoreProvider),
  );
});
