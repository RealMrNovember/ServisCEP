import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/core/database/app_database.dart';
import 'package:serviscep/core/models/doc_item_draft.dart';
import 'package:serviscep/core/network/api_client.dart';
import 'package:serviscep/core/network/sync_api_client.dart';
import 'package:serviscep/core/sync/sync_service.dart';
import 'package:serviscep/features/finance/data/finance_repository.dart';
import 'package:serviscep/features/quotes/data/quotes_repository.dart';
import 'package:serviscep/features/service_requests/data/service_requests_repository.dart';

import '../../support/fake_sync_api_client.dart';
import '../../support/fake_token_store.dart';
import '../../support/in_memory_database.dart';

const _companyId = 'company-1';
const _customerId = 'customer-1';

/// Senkron kapsam genişletmesi (dikey dilim 2) — ServiceRequest, Quote,
/// Proforma, Payment, Income/Expense outbox + push/pull davranışları.
void main() {
  late AppDatabase db;
  late FakeSyncApiClient api;

  setUp(() async {
    db = createInMemoryDatabase();
    api = FakeSyncApiClient();
    await db
        .into(db.companies)
        .insert(CompaniesCompanion.insert(id: _companyId, name: 'Test Co'));
    await db
        .into(db.customers)
        .insert(
          CustomersCompanion.insert(
            id: _customerId,
            companyId: _companyId,
            code: 'CUS-1',
            contactName: const Value('Test Müşteri'),
          ),
        );
  });

  tearDown(() => db.close());

  SyncService buildService() =>
      SyncService(db, api, FakeTokenStore(initialToken: 'test-token'));

  test('teklif oluşturma, kalemleriyle birlikte CREATE outbox satırı düşer '
      've push sonrası SYNCED olur', () async {
    final repo = QuotesRepository(db);
    final quote = await repo.create(
      companyId: _companyId,
      customerId: _customerId,
      items: [
        DocItemDraft(
          description: 'Kamera montajı',
          quantity: 2,
          unit: 'adet',
          unitPriceMinor: 150000,
          taxRate: 20,
          discountMinor: 0,
        ),
      ],
      notes: 'Not',
    );

    final ops = await db.select(db.syncOperations).get();
    expect(ops, hasLength(1));
    expect(ops.single.entityType, 'quote');
    expect(ops.single.operation, 'CREATE');
    final payload = jsonDecode(ops.single.payload) as Map<String, dynamic>;
    expect(payload['customer_id'], _customerId);
    final items = payload['items'] as List<dynamic>;
    expect(items, hasLength(1));
    expect(
      (items.single as Map<String, dynamic>)['description'],
      'Kamera montajı',
    );

    api.quoteResponses.add(SyncEntityResult(id: quote.id, version: 1));
    await buildService().runOnce(_companyId);

    expect(await db.select(db.syncOperations).get(), isEmpty);
    final synced = await (db.select(
      db.quotes,
    )..where((q) => q.id.equals(quote.id))).getSingle();
    expect(synced.syncStatus, 'SYNCED');
    expect(api.createQuoteCalls, hasLength(1));
  });

  test('teklif durum güncellemesi versiyonlu UPDATE kuyruklar', () async {
    final repo = QuotesRepository(db);
    final quote = await repo.create(
      companyId: _companyId,
      customerId: _customerId,
      items: [
        DocItemDraft(
          description: 'X',
          quantity: 1,
          unit: 'adet',
          unitPriceMinor: 100,
          taxRate: 20,
          discountMinor: 0,
        ),
      ],
    );
    // CREATE satırını temizle ki yalnızca UPDATE'i inceleyelim.
    await db.delete(db.syncOperations).go();

    await repo.updateStatus(quote.id, 'KABUL_EDILDI');

    final ops = await db.select(db.syncOperations).get();
    expect(ops, hasLength(1));
    expect(ops.single.operation, 'UPDATE');
    expect(ops.single.baseVersion, 1);
    expect(
      (jsonDecode(ops.single.payload) as Map<String, dynamic>)['status'],
      'KABUL_EDILDI',
    );
  });

  test('talep dönüşümü TEK bir CONVERT operasyonu kuyruklar (ayrıca job '
      'CREATE kuyruklanmaz) ve push, işi sunucu türetmesiyle hizalar', () async {
    final repo = ServiceRequestsRepository(db);
    final request = await repo.create(
      companyId: _companyId,
      customerId: _customerId,
      description: 'Kombi arızalı, yanmıyor',
      priority: 'YUKSEK',
    );
    await db.delete(db.syncOperations).go(); // CREATE satırını temizle

    final job = await repo.convertToJob(
      await (db.select(
        db.serviceRequests,
      )..where((r) => r.id.equals(request.id))).getSingle(),
    );

    final ops = await db.select(db.syncOperations).get();
    expect(ops, hasLength(1), reason: 'job CREATE kuyruklanmamalı');
    expect(ops.single.entityType, 'service_request');
    expect(ops.single.operation, 'CONVERT');
    expect(
      (jsonDecode(ops.single.payload) as Map<String, dynamic>)['job_id'],
      job.id,
    );

    api.convertResponses.add({
      'id': job.id,
      'code': 'J-ABC12345',
      'title': 'Kombi arızalı, yanmıyor',
      'description': 'Kombi arızalı, yanmıyor',
      'version': 1,
    });
    await buildService().runOnce(_companyId);

    expect(api.convertCalls, [(request.id, job.id)]);
    final syncedJob = await (db.select(
      db.jobs,
    )..where((j) => j.id.equals(job.id))).getSingle();
    expect(syncedJob.code, 'J-ABC12345');
    expect(syncedJob.syncStatus, 'SYNCED');
    final syncedRequest = await (db.select(
      db.serviceRequests,
    )..where((r) => r.id.equals(request.id))).getSingle();
    expect(syncedRequest.syncStatus, 'SYNCED');
    expect(await db.select(db.syncOperations).get(), isEmpty);
  });

  test('tahsilat push edilirken customer_id gövdeden ayıklanıp URL yoluna '
      'gider', () async {
    final repo = FinanceRepository(db);
    await repo.recordPayment(
      companyId: _companyId,
      customerId: _customerId,
      amountMinor: 50000,
      method: 'Nakit',
    );

    await buildService().runOnce(_companyId);

    expect(api.createPaymentCalls, hasLength(1));
    final (customerId, body) = api.createPaymentCalls.single;
    expect(customerId, _customerId);
    expect(body.containsKey('customer_id'), isFalse);
    expect(body['amount_minor'], 50000);
    expect(await db.select(db.syncOperations).get(), isEmpty);
  });

  test('gelir ve gider kayıtları CREATE olarak push edilir', () async {
    final repo = FinanceRepository(db);
    await repo.addIncome(
      companyId: _companyId,
      description: 'Servis bedeli',
      amountMinor: 120000,
      category: 'Servis',
    );
    await repo.addExpense(
      companyId: _companyId,
      description: 'Kablo',
      amountMinor: 30000,
      category: 'Malzeme',
    );

    await buildService().runOnce(_companyId);

    expect(api.createIncomeCalls, hasLength(1));
    expect(api.createExpenseCalls, hasLength(1));
    expect(await db.select(db.syncOperations).get(), isEmpty);
  });

  test('quote pull, kalemleri sunucudakiyle değiştirir', () async {
    api.quotesToPull = [
      RemoteRecord(
        id: 'q-remote',
        version: 2,
        raw: {
          'id': 'q-remote',
          'code': 'QTE-9',
          'customer_id': _customerId,
          'status': 'GONDERILDI',
          'notes': null,
          'total_minor': 240000,
          'version': 2,
          'items': [
            {
              'id': 'qi-1',
              'description': 'Sunucu kalemi',
              'quantity': 2,
              'unit': 'adet',
              'unit_price_minor': 120000,
              'tax_rate': 20,
              'discount_minor': 0,
            },
          ],
        },
      ),
    ];

    await buildService().runOnce(_companyId);

    final quote = await (db.select(
      db.quotes,
    )..where((q) => q.id.equals('q-remote'))).getSingle();
    expect(quote.status, 'GONDERILDI');
    expect(quote.version, 2);
    expect(quote.syncStatus, 'SYNCED');
    final items = await (db.select(
      db.quoteItems,
    )..where((i) => i.quoteId.equals('q-remote'))).get();
    expect(items, hasLength(1));
    expect(items.single.description, 'Sunucu kalemi');
  });

  test('402 (abonelik doldu) kuyruk satırlarını PENDING bırakır - FAILED '
      'işaretlenmez, yenileme sonrası akar', () async {
    final repo = FinanceRepository(db);
    await repo.recordPayment(
      companyId: _companyId,
      customerId: _customerId,
      amountMinor: 50000,
    );
    api.paymentResponses.add(
      ApiException(402, 'Aboneliğinin süresi dolmuş.'),
    );

    await buildService().runOnce(_companyId);

    final ops = await db.select(db.syncOperations).get();
    expect(ops, hasLength(1));
    expect(ops.single.status, 'PENDING');
    expect(ops.single.attemptCount, 0);
  });

  test('talep pull, PENDING outbox girdisi olmayan kaydı uygular', () async {
    api.serviceRequestsToPull = [
      RemoteRecord(
        id: 'sr-remote',
        version: 3,
        raw: {
          'id': 'sr-remote',
          'code': 'REQ-5',
          'customer_id': _customerId,
          'description': 'Ofisten girilen talep',
          'priority': 'NORMAL',
          'address': null,
          'status': 'ISLEME_ALINDI',
          'converted_job_id': null,
          'version': 3,
        },
      ),
    ];

    await buildService().runOnce(_companyId);

    final request = await (db.select(
      db.serviceRequests,
    )..where((r) => r.id.equals('sr-remote'))).getSingle();
    expect(request.description, 'Ofisten girilen talep');
    expect(request.status, 'ISLEME_ALINDI');
    expect(request.version, 3);
  });
}
