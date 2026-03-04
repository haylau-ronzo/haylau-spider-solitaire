import '../../game/model/difficulty.dart';

enum DealChoiceMode { daily, random }

class DealChoice {
  const DealChoice({
    required this.difficulty,
    required this.mode,
    required this.guaranteed,
    required this.seed,
    this.dateKey,
  });

  final Difficulty difficulty;
  final DealChoiceMode mode;
  final bool guaranteed;
  final int seed;
  final String? dateKey;

  String get modeLabel => mode == DealChoiceMode.daily ? 'Daily' : 'Random';

  String get guaranteeLabel => guaranteed ? 'Guaranteed' : 'TotallyRandom';
}
