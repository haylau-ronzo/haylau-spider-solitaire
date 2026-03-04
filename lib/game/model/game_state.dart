import 'deal_source.dart';
import 'difficulty.dart';
import 'piles.dart';

class GameState {
  const GameState({
    required this.tableau,
    required this.stock,
    required this.foundations,
    required this.difficulty,
    required this.dealSource,
    required this.seed,
    required this.startedAt,
    required this.moves,
    required this.hintsUsed,
    this.undosUsed = 0,
    this.redosUsed = 0,
    this.restartsUsed = 0,
  });

  final TableauPiles tableau;
  final StockPile stock;
  final Foundations foundations;
  final Difficulty difficulty;
  final DealSource dealSource;
  final int seed;
  final DateTime startedAt;
  final int moves;
  final int hintsUsed;
  final int undosUsed;
  final int redosUsed;
  final int restartsUsed;

  GameState copyWith({
    TableauPiles? tableau,
    StockPile? stock,
    Foundations? foundations,
    Difficulty? difficulty,
    DealSource? dealSource,
    int? seed,
    DateTime? startedAt,
    int? moves,
    int? hintsUsed,
    int? undosUsed,
    int? redosUsed,
    int? restartsUsed,
  }) {
    return GameState(
      tableau: tableau ?? this.tableau,
      stock: stock ?? this.stock,
      foundations: foundations ?? this.foundations,
      difficulty: difficulty ?? this.difficulty,
      dealSource: dealSource ?? this.dealSource,
      seed: seed ?? this.seed,
      startedAt: startedAt ?? this.startedAt,
      moves: moves ?? this.moves,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      undosUsed: undosUsed ?? this.undosUsed,
      redosUsed: redosUsed ?? this.redosUsed,
      restartsUsed: restartsUsed ?? this.restartsUsed,
    );
  }
}
