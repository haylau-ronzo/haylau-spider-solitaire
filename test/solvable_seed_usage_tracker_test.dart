import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/game/model/deal_source.dart';
import 'package:haylau_spider_solitaire/game/model/difficulty.dart';
import 'package:haylau_spider_solitaire/game/persistence/solvable_seed_usage_repo.dart';
import 'package:haylau_spider_solitaire/game/solvable/solvable_seed_usage_tracker.dart';

void main() {
  test('completing daily solvable adds to daily used set', () async {
    final repo = InMemorySolvableSeedUsageRepo();

    await recordCompletedSolvableSeedUsage(
      dealSource: const DailySolvableDealSource('2026-03-01'),
      difficulty: Difficulty.oneSuit,
      seed: 120314,
      repo: repo,
    );

    expect(repo.current().dailyUsedSeeds1Suit, contains(120314));
    expect(repo.current().randomUsedSeeds1Suit, isEmpty);
  });

  test('completing random solvable adds to random used set', () async {
    final repo = InMemorySolvableSeedUsageRepo();

    await recordCompletedSolvableSeedUsage(
      dealSource: const RandomSolvableDealSource(42),
      difficulty: Difficulty.oneSuit,
      seed: 346782,
      repo: repo,
    );

    expect(repo.current().randomUsedSeeds1Suit, contains(346782));
    expect(repo.current().dailyUsedSeeds1Suit, isEmpty);
  });

  test(
    'repeated completion of same seed does not increase used count',
    () async {
      final repo = InMemorySolvableSeedUsageRepo();

      await recordCompletedSolvableSeedUsage(
        dealSource: const DailySolvableDealSource('2026-03-01'),
        difficulty: Difficulty.oneSuit,
        seed: 120314,
        repo: repo,
      );

      await recordCompletedSolvableSeedUsage(
        dealSource: const DailySolvableDealSource('2026-03-02'),
        difficulty: Difficulty.oneSuit,
        seed: 120314,
        repo: repo,
      );

      expect(repo.current().dailyUsedSeeds1Suit.length, 1);
    },
  );
}
