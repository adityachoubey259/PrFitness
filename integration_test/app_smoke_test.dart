import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:prfitness/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PrFitness launches without framework exception', (
    WidgetTester tester,
  ) async {
    app.main();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    expect(tester.takeException(), isNull);
    expect(find.byType(Navigator), findsWidgets);
  });
}
