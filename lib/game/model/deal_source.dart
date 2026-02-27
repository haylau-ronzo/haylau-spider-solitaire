sealed class DealSource {
  const DealSource();

  int toSeed();
}

class RandomDealSource extends DealSource {
  const RandomDealSource(this.seed);
  final int seed;

  @override
  int toSeed() => seed;
}

class DailyDealSource extends DealSource {
  const DailyDealSource(this.dateKeyLocal);
  final String dateKeyLocal;

  @override
  int toSeed() {
    var hash = 0;
    for (final unit in dateKeyLocal.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    return hash;
  }
}

class SolvableLibraryDealSource extends DealSource {
  const SolvableLibraryDealSource(this.index);
  final int index;

  @override
  int toSeed() => ((index + 1) * 7919) & 0x7fffffff;
}
