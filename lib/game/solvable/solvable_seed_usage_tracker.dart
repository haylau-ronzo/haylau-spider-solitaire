import '../model/deal_source.dart';
import '../model/difficulty.dart';
import '../persistence/solvable_seed_usage_repo.dart';

Future<void> recordCompletedSolvableSeedUsage({
  required DealSource dealSource,
  required Difficulty difficulty,
  required int seed,
  required SolvableSeedUsageRepo repo,
}) async {
  if (difficulty != Difficulty.oneSuit) {
    return;
  }

  if (dealSource is DailySolvableDealSource) {
    await repo.markDailyUsedSeed1Suit(seed);
    return;
  }

  if (dealSource is RandomSolvableDealSource) {
    await repo.markRandomUsedSeed1Suit(seed);
  }
}

// Backward-compatible alias while callers migrate to completion-based tracking.
Future<void> recordStartedSolvableSeedUsage({
  required DealSource dealSource,
  required Difficulty difficulty,
  required int seed,
  required SolvableSeedUsageRepo repo,
}) {
  return recordCompletedSolvableSeedUsage(
    dealSource: dealSource,
    difficulty: difficulty,
    seed: seed,
    repo: repo,
  );
}
