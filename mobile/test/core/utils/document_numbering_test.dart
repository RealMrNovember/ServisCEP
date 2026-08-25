import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/core/utils/document_numbering.dart';

void main() {
  final today = DateTime(2026, 8, 25);

  test('hiç belge yoksa seri birden başlar', () {
    expect(
      DocumentNumbering.next(
        fallbackPrefix: 'TKF',
        existingCodes: const [],
        today: today,
      ),
      'TKF-2026-00001',
    );
  });

  test('son kullanılan numaradan devam eder', () {
    expect(
      DocumentNumbering.next(
        fallbackPrefix: 'TKF',
        existingCodes: const ['TKF-2026-00001', 'TKF-2026-00002'],
        today: today,
      ),
      'TKF-2026-00003',
    );
  });

  test('kullanıcı numarayı elle değiştirdiyse oradan devam eder', () {
    expect(
      DocumentNumbering.next(
        fallbackPrefix: 'TKF',
        existingCodes: const ['TKF-2026-00001', 'TKF-2026-01500'],
        today: today,
      ),
      'TKF-2026-01501',
    );
  });

  test('kullanıcı ön eki değiştirdiyse yeni ön ek sürdürülür', () {
    expect(
      DocumentNumbering.next(
        fallbackPrefix: 'QTE',
        existingCodes: const ['QTE-2026-00001', 'TEKLIF-2026-00120'],
        today: today,
      ),
      'TEKLIF-2026-00121',
    );
  });

  test('sıfır dolgusunun genişliği korunur', () {
    expect(
      DocumentNumbering.next(
        fallbackPrefix: 'TKF',
        existingCodes: const ['TKF-2026-0100'],
        today: today,
      ),
      'TKF-2026-0101',
    );
  });

  test('yıl değişince sıra başa döner, ön ek korunur', () {
    expect(
      DocumentNumbering.next(
        fallbackPrefix: 'QTE',
        existingCodes: const ['TKF-2025-00412'],
        today: today,
      ),
      'TKF-2026-00001',
    );
  });

  test('silinen kayıt yüzünden kullanılmış numara tekrar verilmez', () {
    // Eski "adet + 1" yöntemi burada TKF-2026-00003 üretip çakışıyordu.
    expect(
      DocumentNumbering.next(
        fallbackPrefix: 'TKF',
        existingCodes: const ['TKF-2026-00001', 'TKF-2026-00003'],
        today: today,
      ),
      'TKF-2026-00004',
    );
  });

  test('desene uymayan numaralar seriyi bozmaz', () {
    expect(
      DocumentNumbering.next(
        fallbackPrefix: 'TKF',
        existingCodes: const ['elle-yazilmis-numara', 'TKF-2026-00007'],
        today: today,
      ),
      'TKF-2026-00008',
    );
  });

  test('boş numara reddedilir', () {
    expect(DocumentNumbering.validate('  '), isNotNull);
    expect(DocumentNumbering.validate('TKF-2026-00001'), isNull);
  });
}
