// Smoke test básico. Testes de integração reais precisam do Firebase
// configurado (flutterfire configure) — ver README.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clube_panda/core/widgets/panda_logo.dart';

void main() {
  testWidgets('PandaLogo renderiza wordmark', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PandaLogo())),
    );
    expect(find.text('Clube Panda'), findsOneWidget);
  });
}
