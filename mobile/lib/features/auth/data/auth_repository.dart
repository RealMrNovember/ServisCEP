import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
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

/// Yerel-öncelikli kimlik doğrulama.
///
/// NOT: Şu an tamamen yerel veritabanına karşı çalışır (backend API'si
/// henüz derinleşmedi — bkz. ROADMAP.md § BUGÜN Mobil Tamamlama Planı).
/// Parolalar tuzlanmış SHA-256 ile hash'lenir. Backend Phase 3
/// derinleştiğinde bu katman, sunucu tabanlı authentication'a (bkz.
/// docs/07) genişletilecektir — arayüz ekranları değişmeyecektir.
class AuthRepository {
  AuthRepository(this._db, this._storage);

  final AppDatabase _db;
  final FlutterSecureStorage _storage;
  final _uuid = const Uuid();

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  String _generateSalt() {
    final rand = Random.secure();
    return List.generate(16, (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<bool> hasAnyCompany() async {
    final company = await _db.select(_db.companies).getSingleOrNull();
    return company != null;
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

    final companyId = _uuid.v4();
    final userId = _uuid.v4();
    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);

    await _db.into(_db.companies).insert(
      CompaniesCompanion.insert(
        id: companyId,
        name: companyName,
        businessTypes: Value(businessTypes.join(',')),
      ),
    );

    await _db.into(_db.users).insert(
      UsersCompanion.insert(
        id: userId,
        companyId: companyId,
        fullName: ownerFullName,
        email: email,
        phone: Value(phone),
        passwordHash: '$salt\$$hash',
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

  Future<AuthSession> login({required String email, required String password}) async {
    final user = await (_db.select(
      _db.users,
    )..where((u) => u.email.equals(email))).getSingleOrNull();
    if (user == null) {
      throw AuthException('E-posta veya parola hatalı.');
    }

    final parts = user.passwordHash.split(r'$');
    if (parts.length != 2) {
      throw AuthException('Hesap bilgisi bozuk, lütfen destekle iletişime geçin.');
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

  Future<void> _persistSession({required String userId, required String companyId}) async {
    await _storage.write(key: _sessionUserIdKey, value: userId);
    await _storage.write(key: _sessionCompanyIdKey, value: companyId);
  }

  Future<AuthSession?> restoreSession() async {
    final userId = await _storage.read(key: _sessionUserIdKey);
    final companyId = await _storage.read(key: _sessionCompanyIdKey);
    if (userId == null || companyId == null) return null;

    final user = await (_db.select(_db.users)..where((u) => u.id.equals(userId))).getSingleOrNull();
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
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(databaseProvider), ref.watch(secureStorageProvider));
});
