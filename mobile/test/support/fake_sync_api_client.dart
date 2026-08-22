import 'package:serviscep/core/network/sync_api_client.dart';

/// Elle yazılmış sahte — bkz. dart/testing.md "Fakes Over Mocks". Her
/// çağrı türü için ne olacağını sıraya koyarak (`enqueue*`) veya sabit bir
/// davranış atayarak (`nextCreateResult` vb.) yönlendirilir.
class FakeSyncApiClient implements SyncApiClient {
  final List<Map<String, dynamic>> createCustomerCalls = [];
  final List<(String, Map<String, dynamic>)> updateCustomerCalls = [];
  final List<String> deleteCustomerCalls = [];
  final List<Map<String, dynamic>> createJobCalls = [];
  final List<(String, Map<String, dynamic>)> updateJobCalls = [];

  /// Sıradaki `createCustomer`/`updateCustomer`/... çağrısında ne
  /// döneceği/fırlatılacağı — yoksa varsayılan olarak version:1 ile
  /// başarı döner.
  final List<Object> customerResponses = [];
  final List<Object> jobResponses = [];

  List<RemoteRecord> customersToPull = [];
  List<RemoteRecord> jobsToPull = [];

  Object _nextOrDefault(List<Object> queue, String id) {
    if (queue.isEmpty) return SyncEntityResult(id: id, version: 1);
    return queue.removeAt(0);
  }

  Future<SyncEntityResult> _resolve(Object outcome) async {
    if (outcome is Exception) throw outcome;
    return outcome as SyncEntityResult;
  }

  @override
  Future<SyncEntityResult> createCustomer(Map<String, dynamic> payload) async {
    createCustomerCalls.add(payload);
    return _resolve(_nextOrDefault(customerResponses, payload['id'] as String));
  }

  @override
  Future<SyncEntityResult> updateCustomer(
    String id,
    Map<String, dynamic> payload,
  ) async {
    updateCustomerCalls.add((id, payload));
    return _resolve(_nextOrDefault(customerResponses, id));
  }

  @override
  Future<void> deleteCustomer(String id) async {
    deleteCustomerCalls.add(id);
  }

  @override
  Future<List<RemoteRecord>> listCustomers() async => customersToPull;

  @override
  Future<SyncEntityResult> createJob(Map<String, dynamic> payload) async {
    createJobCalls.add(payload);
    return _resolve(_nextOrDefault(jobResponses, payload['id'] as String));
  }

  @override
  Future<SyncEntityResult> updateJob(
    String id,
    Map<String, dynamic> payload,
  ) async {
    updateJobCalls.add((id, payload));
    return _resolve(_nextOrDefault(jobResponses, id));
  }

  @override
  Future<List<RemoteRecord>> listJobs() async => jobsToPull;

  @override
  Future<AuthTokenResult> register({
    required String companyName,
    String? businessTypes,
    required String fullName,
    required String email,
    String? phone,
    required String password,
  }) {
    throw UnimplementedError('Bu test seti auth akışını kapsamıyor.');
  }

  @override
  Future<AuthTokenResult> loginWithGoogle(String idToken) {
    throw UnimplementedError('Bu test seti auth akışını kapsamıyor.');
  }

  @override
  Future<AuthTokenResult> registerWithGoogle({
    required String idToken,
    required String companyName,
    String? businessTypes,
    String? phone,
  }) {
    throw UnimplementedError('Bu test seti auth akışını kapsamıyor.');
  }

  @override
  Future<AuthTokenResult> login({
    required String email,
    required String password,
  }) {
    throw UnimplementedError('Bu test seti auth akışını kapsamıyor.');
  }
}
