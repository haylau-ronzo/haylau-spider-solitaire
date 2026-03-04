import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/features/daily/daily_calendar_logic.dart';

void main() {
  test(
    'completedOnDay is true only when completion local date matches deal date',
    () {
      final sameDay = DateTime(2026, 3, 1, 23, 59);
      final nextDay = DateTime(2026, 3, 2, 0, 1);

      expect(
        isCompletedOnDay(dateKeyLocal: '2026-03-01', completedAt: sameDay),
        isTrue,
      );
      expect(
        isCompletedOnDay(dateKeyLocal: '2026-03-01', completedAt: nextDay),
        isFalse,
      );
    },
  );

  test('future day disabled logic treats only dates after today as future', () {
    final today = DateTime(2026, 3, 1, 12, 0);

    expect(isFutureDateKey('2026-03-02', today), isTrue);
    expect(isFutureDateKey('2026-03-01', today), isFalse);
    expect(isFutureDateKey('2026-02-28', today), isFalse);
  });
}
