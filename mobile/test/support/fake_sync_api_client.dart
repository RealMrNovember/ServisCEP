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

  final List<Map<String, dynamic>> createServiceRequestCalls = [];
  final List<(String, String)> convertCalls = [];
  final List<Map<String, dynamic>> createQuoteCalls = [];
  final List<(String, Map<String, dynamic>)> updateQuoteCalls = [];
  final List<Map<String, dynamic>> createProformaCalls = [];
  final List<(String, Map<String, dynamic>)> createPaymentCalls = [];
  final List<Map<String, dynamic>> createIncomeCalls = [];
  final List<Map<String, dynamic>> createExpenseCalls = [];
  final List<(String, Map<String, dynamic>)> createJobNoteCalls = [];
  final List<(String, String, String, String)> createJobPhotoCalls = [];
  final List<(String, String, String, String)> createJobSignatureCalls = [];

  /// Sıradaki `createCustomer`/`updateCustomer`/... çağrısında ne
  /// döneceği/fırlatılacağı — yoksa varsayılan olarak version:1 ile
  /// başarı döner.
  final List<Object> customerResponses = [];
  final List<Object> jobResponses = [];
  final List<Object> serviceRequestResponses = [];
  final List<Object> quoteResponses = [];
  final List<Object> proformaResponses = [];
  final List<Object> paymentResponses = [];
  final List<Object> convertResponses = [];

  final List<(String, String)> uploadTaxCertificateCalls = [];
  final List<Map<String, dynamic>> updateCompanyCalls = [];
  final List<Map<String, dynamic>> updateProfileCalls = [];
  final List<(String, String)> updatePasswordCalls = [];
  final List<Map<String, dynamic>> createPersonnelCalls = [];
  final List<(String, Map<String, dynamic>)> updatePersonnelCalls = [];
  final List<String> deletePersonnelCalls = [];
  List<Map<String, dynamic>> personnel = [];
  List<RemoteRecord> ledgerToPull = [];
  final List<(String, String)> resolveConflictCalls = [];
  List<Map<String, dynamic>> pendingConflicts = [];

  List<RemoteRecord> customersToPull = [];
  List<RemoteRecord> trashedCustomersToPull = [];
  List<RemoteRecord> jobsToPull = [];
  List<RemoteRecord> serviceRequestsToPull = [];
  List<RemoteRecord> quotesToPull = [];
  List<RemoteRecord> proformasToPull = [];

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
  Future<List<RemoteRecord>> listTrashedCustomers() async =>
      trashedCustomersToPull;

  @override
  Future<void> uploadTaxCertificate(String customerId, String filePath) async {
    uploadTaxCertificateCalls.add((customerId, filePath));
  }

  @override
  Future<void> updateCompany(Map<String, dynamic> payload) async {
    updateCompanyCalls.add(payload);
  }

  @override
  Future<void> updateProfile(Map<String, dynamic> payload) async {
    updateProfileCalls.add(payload);
  }

  @override
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    updatePasswordCalls.add((currentPassword, newPassword));
  }

  @override
  Future<List<RemoteRecord>> listLedgerEntries() async => ledgerToPull;

  @override
  Future<List<Map<String, dynamic>>> listPersonnel() async => personnel;

  @override
  Future<Map<String, dynamic>> createPersonnel(
    Map<String, dynamic> payload,
  ) async {
    createPersonnelCalls.add(payload);
    return {...payload, 'id': 'new-user'};
  }

  @override
  Future<void> updatePersonnel(String id, Map<String, dynamic> payload) async {
    updatePersonnelCalls.add((id, payload));
  }

  @override
  Future<void> deletePersonnel(String id) async {
    deletePersonnelCalls.add(id);
  }

  @override
  Future<List<Map<String, dynamic>>> listPendingConflicts() async =>
      pendingConflicts;

  @override
  Future<void> resolveConflict(String conflictId, String resolution) async {
    resolveConflictCalls.add((conflictId, resolution));
  }

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
  Future<SyncEntityResult> createServiceRequest(
    Map<String, dynamic> payload,
  ) async {
    createServiceRequestCalls.add(payload);
    return _resolve(
      _nextOrDefault(serviceRequestResponses, payload['id'] as String),
    );
  }

  @override
  Future<Map<String, dynamic>> convertServiceRequest(
    String id,
    String jobId,
  ) async {
    convertCalls.add((id, jobId));
    if (convertResponses.isNotEmpty) {
      final outcome = convertResponses.removeAt(0);
      if (outcome is Exception) throw outcome;
      return outcome as Map<String, dynamic>;
    }
    return {
      'id': jobId,
      'code': 'J-SERVER01',
      'title': 'Sunucu başlığı',
      'description': 'Sunucu açıklaması',
      'version': 1,
    };
  }

  @override
  Future<List<RemoteRecord>> listServiceRequests() async =>
      serviceRequestsToPull;

  @override
  Future<SyncEntityResult> createQuote(Map<String, dynamic> payload) async {
    createQuoteCalls.add(payload);
    return _resolve(_nextOrDefault(quoteResponses, payload['id'] as String));
  }

  @override
  Future<SyncEntityResult> updateQuote(
    String id,
    Map<String, dynamic> payload,
  ) async {
    updateQuoteCalls.add((id, payload));
    return _resolve(_nextOrDefault(quoteResponses, id));
  }

  @override
  Future<List<RemoteRecord>> listQuotes() async => quotesToPull;

  @override
  Future<SyncEntityResult> createProforma(Map<String, dynamic> payload) async {
    createProformaCalls.add(payload);
    return _resolve(_nextOrDefault(proformaResponses, payload['id'] as String));
  }

  @override
  Future<List<RemoteRecord>> listProformas() async => proformasToPull;

  @override
  Future<SyncEntityResult> createPayment(
    String customerId,
    Map<String, dynamic> payload,
  ) async {
    createPaymentCalls.add((customerId, payload));
    return _resolve(_nextOrDefault(paymentResponses, payload['id'] as String));
  }

  @override
  Future<SyncEntityResult> createIncomeEntry(
    Map<String, dynamic> payload,
  ) async {
    createIncomeCalls.add(payload);
    return SyncEntityResult(id: payload['id'] as String, version: 1);
  }

  @override
  Future<SyncEntityResult> createExpenseEntry(
    Map<String, dynamic> payload,
  ) async {
    createExpenseCalls.add(payload);
    return SyncEntityResult(id: payload['id'] as String, version: 1);
  }

  @override
  Future<SyncEntityResult> createJobNote(
    String jobId,
    Map<String, dynamic> payload,
  ) async {
    createJobNoteCalls.add((jobId, payload));
    return SyncEntityResult(id: payload['id'] as String, version: 1);
  }

  @override
  Future<SyncEntityResult> createJobPhoto(
    String jobId, {
    required String id,
    required String category,
    required String filePath,
  }) async {
    createJobPhotoCalls.add((jobId, id, category, filePath));
    return SyncEntityResult(id: id, version: 1);
  }

  @override
  Future<SyncEntityResult> createJobSignature(
    String jobId, {
    required String id,
    required String signerName,
    required String filePath,
  }) async {
    createJobSignatureCalls.add((jobId, id, signerName, filePath));
    return SyncEntityResult(id: id, version: 1);
  }

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
