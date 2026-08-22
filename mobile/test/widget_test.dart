import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:serviscep/features/auth/login_screen.dart';

/// NOT: Tam uygulama akışı (auth + yerel veritabanı + secure storage)
/// widget test ortamında native platform channel'lar olmadan
/// çalışmadığından (flutter_secure_storage, drift/sqlite3), burada yalnızca
/// bağımsız ekranlar test edilir. Uçtan uca doğrulama gerçek cihaz/emülatörde
/// `flutter run` veya `flutter build apk` ile yapılır.
void main() {
  testWidgets('Giriş ekranı temel alanları gösterir', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tekrar hoş geldin'), findsOneWidget);
    expect(find.text('Giriş yap'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
  });
}
