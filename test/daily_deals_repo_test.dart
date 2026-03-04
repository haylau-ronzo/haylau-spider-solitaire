import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/game/persistence/daily_deals_model.dart';
import 'package:haylau_spider_solitaire/game/persistence/daily_deals_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('daily completion record persists across repo reload', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final repo1 = LocalDailyDealsRepo();
    await repo1.load();
    await repo1.markCompleted(
      dateKeyLocal: '2026-03-01',
      completedAt: DateTime(2026, 3, 1, 20, 0),
      metrics: const DailyCompletionMetrics(
        score: 12345,
        timeSeconds: 600,
        moves: 180,
        undos: 2,
        hints: 1,
      ),
    );

    final repo2 = LocalDailyDealsRepo();
    final reloaded = await repo2.load();
    final record = reloaded.recordsByDateKey['2026-03-01'];

    expect(record, isNotNull);
    expect(record!.status.name, 'completed');
    expect(record.metrics!.score, 12345);
  });
}
