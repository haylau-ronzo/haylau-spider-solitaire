import '../model/difficulty.dart';

class StatsModel {
  const StatsModel({
    required this.lifetimeTotalScore,
    required this.totalGamesStarted,
    required this.totalGamesCompleted,
    required this.totalMoves,
    required this.totalUndos,
    required this.totalRedos,
    required this.totalHints,
    required this.winsByDifficulty,
    required this.bestScoreByDifficulty,
    required this.bestTimeByDifficulty,
  });

  static const empty = StatsModel(
    lifetimeTotalScore: 0,
    totalGamesStarted: 0,
    totalGamesCompleted: 0,
    totalMoves: 0,
    totalUndos: 0,
    totalRedos: 0,
    totalHints: 0,
    winsByDifficulty: {},
    bestScoreByDifficulty: {},
    bestTimeByDifficulty: {},
  );

  final int lifetimeTotalScore;
  final int totalGamesStarted;
  final int totalGamesCompleted;
  final int totalMoves;
  final int totalUndos;
  final int totalRedos;
  final int totalHints;
  final Map<Difficulty, int> winsByDifficulty;
  final Map<Difficulty, int> bestScoreByDifficulty;
  final Map<Difficulty, int> bestTimeByDifficulty;

  StatsModel copyWith({
    int? lifetimeTotalScore,
    int? totalGamesStarted,
    int? totalGamesCompleted,
    int? totalMoves,
    int? totalUndos,
    int? totalRedos,
    int? totalHints,
    Map<Difficulty, int>? winsByDifficulty,
    Map<Difficulty, int>? bestScoreByDifficulty,
    Map<Difficulty, int>? bestTimeByDifficulty,
  }) {
    return StatsModel(
      lifetimeTotalScore: lifetimeTotalScore ?? this.lifetimeTotalScore,
      totalGamesStarted: totalGamesStarted ?? this.totalGamesStarted,
      totalGamesCompleted: totalGamesCompleted ?? this.totalGamesCompleted,
      totalMoves: totalMoves ?? this.totalMoves,
      totalUndos: totalUndos ?? this.totalUndos,
      totalRedos: totalRedos ?? this.totalRedos,
      totalHints: totalHints ?? this.totalHints,
      winsByDifficulty: winsByDifficulty ?? this.winsByDifficulty,
      bestScoreByDifficulty:
          bestScoreByDifficulty ?? this.bestScoreByDifficulty,
      bestTimeByDifficulty: bestTimeByDifficulty ?? this.bestTimeByDifficulty,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'lifetimeTotalScore': lifetimeTotalScore,
      'totalGamesStarted': totalGamesStarted,
      'totalGamesCompleted': totalGamesCompleted,
      'totalMoves': totalMoves,
      'totalUndos': totalUndos,
      'totalRedos': totalRedos,
      'totalHints': totalHints,
      'winsByDifficulty': _encodeDifficultyMap(winsByDifficulty),
      'bestScoreByDifficulty': _encodeDifficultyMap(bestScoreByDifficulty),
      'bestTimeByDifficulty': _encodeDifficultyMap(bestTimeByDifficulty),
    };
  }

  static StatsModel fromJson(Map<String, dynamic> json) {
    return StatsModel(
      lifetimeTotalScore: json['lifetimeTotalScore'] as int? ?? 0,
      totalGamesStarted: json['totalGamesStarted'] as int? ?? 0,
      totalGamesCompleted: json['totalGamesCompleted'] as int? ?? 0,
      totalMoves: json['totalMoves'] as int? ?? 0,
      totalUndos: json['totalUndos'] as int? ?? 0,
      totalRedos: json['totalRedos'] as int? ?? 0,
      totalHints: json['totalHints'] as int? ?? 0,
      winsByDifficulty: _decodeDifficultyMap(
        json['winsByDifficulty'] as Map<String, dynamic>?,
      ),
      bestScoreByDifficulty: _decodeDifficultyMap(
        json['bestScoreByDifficulty'] as Map<String, dynamic>?,
      ),
      bestTimeByDifficulty: _decodeDifficultyMap(
        json['bestTimeByDifficulty'] as Map<String, dynamic>?,
      ),
    );
  }

  static Map<String, dynamic> _encodeDifficultyMap(
    Map<Difficulty, int> source,
  ) {
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      result[entry.key.name] = entry.value;
    }
    return result;
  }

  static Map<Difficulty, int> _decodeDifficultyMap(
    Map<String, dynamic>? source,
  ) {
    if (source == null) {
      return <Difficulty, int>{};
    }
    final result = <Difficulty, int>{};
    for (final entry in source.entries) {
      final name = entry.key;
      final value = entry.value;
      final difficulty = Difficulty.values.where((d) => d.name == name);
      if (difficulty.isEmpty || value is! int) {
        continue;
      }
      result[difficulty.first] = value;
    }
    return result;
  }
}
