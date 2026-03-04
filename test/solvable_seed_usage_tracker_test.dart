import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/game/model/deal_source.dart';
import 'package:haylau_spider_solitaire/game/model/difficulty.dart';
import 'package:haylau_spider_solitaire/game/persistence/solvable_seed_usage_repo.dart';
import 'package:haylau_spider_solitaire/game/solvable/solvable_seed_usage_tracker.dart';
import 'package:haylau_spider_solitaire/game/solvable/solvable_seeds.dart';

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
  test(
    'starting guaranteed random deals increases used count and avoids reuse while available',
    () async {
      final repo = InMemorySolvableSeedUsageRepo();
      final pool = winnableSeedsForDifficulty(Difficulty.oneSuit);
      if (pool.isEmpty) {
        expect(repo.current().randomUsedSeeds1Suit, isEmpty);
        return;
      }

      var nextIndex = 0;
      final pickedSeeds = <int>[];

      for (var i = 0; i < 3; i++) {
        final used = <int>{
          ...repo.current().dailyUsedSeeds1Suit,
          ...repo.current().randomUsedSeeds1Suit,
        };
        final selectedIndex = pickGuaranteedRandomPoolIndexPreferUnused(
          pool: pool,
          usedSeeds: used,
          nextIndex: nextIndex,
        );
        final seed = pool[selectedIndex];
        pickedSeeds.add(seed);

        await recordStartedSolvableSeedUsage(
          dealSource: RandomSolvableDealSource(selectedIndex),
          difficulty: Difficulty.oneSuit,
          seed: seed,
          repo: repo,
        );

        nextIndex = selectedIndex + 1;
      }

      final expectedUsed = pool.length < 3 ? pool.length : 3;
      expect(repo.current().randomUsedSeeds1Suit.length, expectedUsed);
      if (pool.length > 1 && pickedSeeds.length > 1) {
        expect(pickedSeeds[0], isNot(pickedSeeds[1]));
      }
    },
  );
}
