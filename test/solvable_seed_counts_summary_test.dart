import 'package:flutter_test/flutter_test.dart';
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

      expect(summary.daily1SuitTotal, dailySolvableSeeds1Suit.length);
      expect(summary.random1SuitTotal, randomSolvableSeeds1Suit.length);
      expect(
        summary.daily1SuitUsed,
        inInclusiveRange(0, summary.daily1SuitTotal),
      );
      expect(
        summary.random1SuitUsed,
        inInclusiveRange(0, summary.random1SuitTotal),
      );
    },
  );

  test(
    'solvable seed counts summary ignores stale seeds not in current pools',
    () async {
      final repo = InMemorySolvableSeedUsageRepo();

      await repo.markDailyUsedSeed1Suit(99999999);
      await repo.markRandomUsedSeed1Suit(88888888);

      final summary = buildSolvableSeedCountsSummary(repo.current());

      expect(summary.daily1SuitUsed, 0);
      expect(summary.random1SuitUsed, 0);
    },
  );
}
