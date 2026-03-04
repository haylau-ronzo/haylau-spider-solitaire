import '../solvable/solvable_seeds.dart';
import 'difficulty.dart';

sealed class DealSource {
  const DealSource();

  int toSeed({required Difficulty difficulty});
}

class RandomDealSource extends DealSource {
  const RandomDealSource(this.seed);
  final int seed;

  @override
  int toSeed({required Difficulty difficulty}) => seed;
}

class DailyDealSource extends DealSource {
  const DailyDealSource(this.dateKeyLocal);
  final String dateKeyLocal;

  @override
  int toSeed({required Difficulty difficulty}) {
    return _hashDateKey(dateKeyLocal);
  }
}

class DailySolvableDealSource extends DealSource {
  const DailySolvableDealSource(this.dateKeyLocal);
  final String dateKeyLocal;

  @override
  int toSeed({required Difficulty difficulty}) {
    if (!hasDailySolvableSeeds(difficulty)) {
      return _hashDateKey(dateKeyLocal);
    }

    return pickDailySolvableSeed(difficulty: difficulty, dateKey: dateKeyLocal);
  }
}

class RandomSolvableDealSource extends DealSource {
  const RandomSolvableDealSource(this.index);
  final int index;

  @override
  int toSeed({required Difficulty difficulty}) {
    return pickRandomSolvableSeed(difficulty: difficulty, index: index);
  }
}

int _hashDateKey(String dateKeyLocal) {
  var hash = 0;
  for (final unit in dateKeyLocal.codeUnits) {
    hash = ((hash * 31) + unit) & 0x7fffffff;
  }
  return hash;
}
