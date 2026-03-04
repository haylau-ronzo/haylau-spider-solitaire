import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/app/app_services.dart';
import 'package:haylau_spider_solitaire/features/daily/daily_calendar_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('tapping a non-future day opens day details panel', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppServices.dailyDealsRepo.load();

    await tester.pumpWidget(const MaterialApp(home: DailyCalendarScreen()));

    await tester.pumpAndSettle();

    final today = DateTime.now().day.toString();
    await tester.tap(find.text(today).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Close'), findsOneWidget);
  });
}
