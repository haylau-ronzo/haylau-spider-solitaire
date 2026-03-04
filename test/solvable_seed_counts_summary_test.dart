import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/game/model/difficulty.dart';
import 'package:haylau_spider_solitaire/game/persistence/solvable_seed_usage_repo.dart';
import 'package:haylau_spider_solitaire/game/solvable/solvable_seed_counts_summary.dart';
import 'package:haylau_spider_solitaire/game/solvable/solvable_seeds.dart';

void main() {
  test(
    'solvable seed counts summary handles empty or populated pools safely',
    () async {
      final repo = InMemorySolvableSeedUsageRepo();

      await repo.markDailyUsedSeed1Suit(120314);
      await repo.markRandomUsedSeed1Suit(346782);

      final summary = buildSolvableSeedCountsSummary(repo.current());
      final oneSuitPool = winnableSeedsForDifficulty(Difficulty.oneSuit);

      expect(summary.oneSuit.total, oneSuitPool.toSet().length);
      expect(summary.oneSuit.used, inInclusiveRange(0, summary.oneSuit.total));
      expect(summary.twoSuit.used, 0);
      expect(summary.fourSuit.used, 0);
    },
  );

  test(
    'solvable seed counts summary uses combined unique used seeds',
    () async {
      final repo = InMemorySolvableSeedUsageRepo();
      final oneSuitPool = winnableSeedsForDifficulty(Difficulty.oneSuit);
      if (oneSuitPool.length < 2) {
        expect(true, isTrue);
        return;
      }

      final seedA = oneSuitPool.first;
      final seedB = oneSuitPool.last;

      await repo.markDailyUsedSeed1Suit(seedA);
      await repo.markRandomUsedSeed1Suit(seedA);
      await repo.markRandomUsedSeed1Suit(seedB);

      final summary = buildSolvableSeedCountsSummary(repo.current());

      expect(summary.oneSuit.used, 2);
    },
  );

  test(
    'solvable seed counts summary ignores stale seeds not in current pools',
    () async {
      final repo = InMemorySolvableSeedUsageRepo();

      await repo.markDailyUsedSeed1Suit(99999999);
      await repo.markRandomUsedSeed1Suit(88888888);

      final summary = buildSolvableSeedCountsSummary(repo.current());

      expect(summary.oneSuit.used, 0);
    },
  );
}
