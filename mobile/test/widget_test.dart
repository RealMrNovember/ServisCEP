import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:serviscep/app/app.dart';

void main() {
  testWidgets('Dashboard ekranı açılır ve başlığı gösterir', (
    WidgetTester tester,
  ) async {
    await initializeDateFormatting('tr_TR');

    await tester.pumpWidget(
      const ProviderScope(child: ServisCepApp()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('işin var'), findsOneWidget);
    expect(find.text('Yeni İş'), findsOneWidget);
  });
}
