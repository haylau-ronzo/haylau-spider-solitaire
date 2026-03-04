import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/app/app_services.dart';
import 'package:haylau_spider_solitaire/features/daily/daily_calendar_screen.dart';
import 'package:haylau_spider_solitaire/features/settings/settings_model.dart';
import 'package:haylau_spider_solitaire/game/model/difficulty.dart';
import 'package:haylau_spider_solitaire/game/solvable/verified_solvable_data_override.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('tapping a non-future day opens day details panel', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.v1':
          '{"difficulty":"oneSuit","tapMode":"onTwoTap","soundsOn":true,"dealRule":"classic","animations":"minimal","previewNextCardOnDrag":false,"orientationLock":"landscape","ignoreVerifiedSolvableData":false}',
    });

    setIgnoreVerifiedSolvableData(false);
    await AppServices.settingsRepo.saveSettings(
      SettingsModel.defaults.copyWith(
        difficulty: Difficulty.oneSuit,
        ignoreVerifiedSolvableData: false,
      ),
    );

    await AppServices.dailyDealsRepo.load();

    await tester.pumpWidget(const MaterialApp(home: DailyCalendarScreen()));
    await tester.pumpAndSettle();

    final today = DateTime.now().day.toString();
    final dayFinder = find.text(today).hitTestable();
    expect(dayFinder, findsAtLeastNWidgets(1));

    await tester.tap(dayFinder.first);
    await tester.pumpAndSettle();

    expect(find.text('Close'), findsOneWidget);
  });
}
