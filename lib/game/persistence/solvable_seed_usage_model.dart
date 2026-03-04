class SolvableSeedUsageModel {
  const SolvableSeedUsageModel({
    required this.dailyUsedSeeds1Suit,
    required this.randomUsedSeeds1Suit,
  });

  static const empty = SolvableSeedUsageModel(
    dailyUsedSeeds1Suit: <int>{},
    randomUsedSeeds1Suit: <int>{},
  );

  // Future-proofing: structure is pool-based and can be extended for 2/4-suit.
  final Set<int> dailyUsedSeeds1Suit;
  final Set<int> randomUsedSeeds1Suit;

  SolvableSeedUsageModel copyWith({
    Set<int>? dailyUsedSeeds1Suit,
    Set<int>? randomUsedSeeds1Suit,
  }) {
    return SolvableSeedUsageModel(
      dailyUsedSeeds1Suit: dailyUsedSeeds1Suit ?? this.dailyUsedSeeds1Suit,
      randomUsedSeeds1Suit: randomUsedSeeds1Suit ?? this.randomUsedSeeds1Suit,
    );
  }

  Map<String, dynamic> toJson() {
    List<int> sorted(Set<int> values) => values.toList()..sort();

    return <String, dynamic>{
      'dailyUsedSeeds1Suit': sorted(dailyUsedSeeds1Suit),
      'randomUsedSeeds1Suit': sorted(randomUsedSeeds1Suit),
    };
  }

  static SolvableSeedUsageModel fromJson(Map<String, dynamic> json) {
    Set<int> parseSet(String key) {
      final raw = json[key];
      if (raw is! List<dynamic>) {
        return <int>{};
      }
      return raw.whereType<num>().map((value) => value.toInt()).toSet();
    }

    return SolvableSeedUsageModel(
      dailyUsedSeeds1Suit: parseSet('dailyUsedSeeds1Suit'),
      randomUsedSeeds1Suit: parseSet('randomUsedSeeds1Suit'),
    );
  }
}
