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
    );
  }
}
