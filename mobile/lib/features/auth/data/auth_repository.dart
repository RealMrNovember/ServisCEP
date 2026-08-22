import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

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
  });

  final String userId;
  final String companyId;
  final String fullName;
  final String companyName;
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
/// Google ile kayıt/giriş hâlâ tamamen yerel (backend'e bağlanmıyor) —
/// bu hesaplar için `SyncService` token bulamadığından sessizce no-op
/// kalır, ROADMAP'te bilinen bir sınır olarak not edilmiştir.
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
  final _uuid = const Uuid();

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

  /// Google ile giriş yapmış bir kullanıcı zaten var mı? — bkz. docs/09
  /// § Kimlik Doğrulama Yöntemleri.
  Future<User?> findUserByEmail(String email) {
    return (_db.select(
      _db.users,
    )..where((u) => u.email.equals(email))).getSingleOrNull();
  }

  /// Google kimliği doğrulanmış bir kullanıcı için oturum açar — parola
  /// kontrolü yapılmaz, Google'ın kendi doğrulaması güvenilir kabul edilir.
  Future<AuthSession> loginVerifiedEmail(String email) async {
    final user = await findUserByEmail(email);
    if (user == null) {
      throw AuthException('Bu e-posta ile kayıtlı hesap yok.');
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
    );
  }

  /// Google ile kayıt — parola gerekmez (Google kimliği doğrulamış sayılır).
  /// `passwordHash` özel bir işaretçi (`GOOGLE_AUTH`) ile doldurulur; bu
  /// hesapla e-posta/parola girişi yapılamaz, yalnızca Google ile.
  Future<AuthSession> registerWithGoogle({
    required String companyName,
    required List<String> businessTypes,
    required String ownerFullName,
    required String email,
  }) async {
    final existing = await findUserByEmail(email);
    if (existing != null) {
      throw AuthException('Bu e-posta ile zaten bir hesap var.');
    }

    final companyId = _uuid.v4();
    final userId = _uuid.v4();

    await _db
        .into(_db.companies)
        .insert(
          CompaniesCompanion.insert(
            id: companyId,
            name: companyName,
            businessTypes: Value(businessTypes.join(',')),
          ),
        );

    await _db
        .into(_db.users)
        .insert(
          UsersCompanion.insert(
            id: userId,
            companyId: companyId,
            fullName: ownerFullName,
            email: email,
            passwordHash: 'GOOGLE_AUTH',
            role: const Value('OWNER'),
          ),
        );

    await _persistSession(userId: userId, companyId: companyId);

    return AuthSession(
      userId: userId,
      companyId: companyId,
      fullName: ownerFullName,
      companyName: companyName,
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
            role: const Value('OWNER'),
          ),
        );

    await _tokenStore.write(result.token);
    await _persistSession(userId: result.userId, companyId: result.companyId);

    return AuthSession(
      userId: result.userId,
      companyId: result.companyId,
      fullName: result.fullName,
      companyName: result.companyName,
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

    final existingCompany = await (_db.select(
      _db.companies,
    )..where((c) => c.id.equals(result.companyId))).getSingleOrNull();
    if (existingCompany == null) {
      await _db
          .into(_db.companies)
          .insert(
            CompaniesCompanion.insert(
              id: result.companyId,
              name: result.companyName,
            ),
          );
    }
    await _db
        .into(_db.users)
        .insert(
          UsersCompanion.insert(
            id: result.userId,
            companyId: result.companyId,
            fullName: result.fullName,
            email: email,
            passwordHash: '$salt\$$hash',
            role: const Value('OWNER'),
          ),
        );

    await _tokenStore.write(result.token);
    await _persistSession(userId: result.userId, companyId: result.companyId);

    return AuthSession(
      userId: result.userId,
      companyId: result.companyId,
      fullName: result.fullName,
      companyName: result.companyName,
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
