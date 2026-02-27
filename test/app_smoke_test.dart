import 'package:flutter_test/flutter_test.dart';

import 'package:haylau_spider_solitaire/app/app.dart';

void main() {
  testWidgets('app boots to home menu', (tester) async {
    await tester.pumpWidget(const SpiderSolitaireApp());
    expect(find.text('Spider Solitaire'), findsOneWidget);
    expect(find.text('Daily Deal'), findsOneWidget);
  });
}
