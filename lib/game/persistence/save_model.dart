import '../actions/auto_complete_run_action.dart';
import '../actions/deal_from_stock_action.dart';
import '../actions/game_action.dart';
import '../actions/move_stack_action.dart';
import '../model/card.dart';
import '../model/deal_source.dart';
import '../model/difficulty.dart';
import '../model/game_state.dart';
import '../model/piles.dart';

class SaveModel {
  const SaveModel({
    required this.slotId,
    required this.gameState,
    required this.savedAt,
    this.undoStack = const <GameAction>[],
    this.redoStack = const <GameAction>[],
  });

  final String slotId;
  final GameState gameState;
  final DateTime savedAt;
  final List<GameAction> undoStack;
  final List<GameAction> redoStack;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'slotId': slotId,
      'savedAt': savedAt.toIso8601String(),
      'gameState': _encodeState(gameState),
      'undoStack': undoStack.map((action) => action.toJson()).toList(),
      'redoStack': redoStack.map((action) => action.toJson()).toList(),
    };
  }

  static SaveModel fromJson(Map<String, dynamic> json) {
    final rawUndo = json['undoStack'] as List<dynamic>?;
    final rawRedo = json['redoStack'] as List<dynamic>?;

    return SaveModel(
      slotId: json['slotId'] as String,
      savedAt: DateTime.parse(json['savedAt'] as String),
      gameState: _decodeState(json['gameState'] as Map<String, dynamic>),
      undoStack: rawUndo == null
          ? const <GameAction>[]
          : rawUndo
                .map((item) => _decodeAction(item as Map<String, dynamic>))
                .toList(),
      redoStack: rawRedo == null
          ? const <GameAction>[]
          : rawRedo
                .map((item) => _decodeAction(item as Map<String, dynamic>))
                .toList(),
    );
  }

  static Map<String, dynamic> _encodeState(GameState state) {
    return <String, dynamic>{
      'difficulty': state.difficulty.name,
      'dealSource': _encodeDealSource(state.dealSource),
      'seed': state.seed,
      'startedAt': state.startedAt.toIso8601String(),
      'moves': state.moves,
      'hintsUsed': state.hintsUsed,
      'undosUsed': state.undosUsed,
      'redosUsed': state.redosUsed,
      'restartsUsed': state.restartsUsed,
      'foundations': state.foundations.completedRuns,
      'tableau': state.tableau.columns
          .map((column) => column.map(_encodeCard).toList())
          .toList(),
      'stock': state.stock.cards.map(_encodeCard).toList(),
    };
  }

  static GameState _decodeState(Map<String, dynamic> json) {
    final tableau = (json['tableau'] as List<dynamic>)
        .map(
          (column) => (column as List<dynamic>)
              .map((card) => _decodeCard(card as Map<String, dynamic>))
              .toList(),
        )
        .toList();
    final stock = (json['stock'] as List<dynamic>)
        .map((card) => _decodeCard(card as Map<String, dynamic>))
        .toList();

    return GameState(
      tableau: TableauPiles(tableau),
      stock: StockPile(stock),
      foundations: Foundations(completedRuns: json['foundations'] as int),
      difficulty: Difficulty.values.byName(json['difficulty'] as String),
      dealSource: _decodeDealSource(json['dealSource'] as Map<String, dynamic>),
      seed: json['seed'] as int,
      startedAt: DateTime.parse(json['startedAt'] as String),
      moves: json['moves'] as int,
      hintsUsed: json['hintsUsed'] as int,
      undosUsed: json['undosUsed'] as int? ?? 0,
      redosUsed: json['redosUsed'] as int? ?? 0,
      restartsUsed: json['restartsUsed'] as int? ?? 0,
    );
  }

  static Map<String, dynamic> _encodeDealSource(DealSource source) {
    return switch (source) {
      RandomDealSource _ => <String, dynamic>{
        'type': 'random',
        'seed': source.seed,
      },
      DailyDealSource _ => <String, dynamic>{
        'type': 'daily',
        'dateKeyLocal': source.dateKeyLocal,
      },
      DailySolvableDealSource _ => <String, dynamic>{
        'type': 'dailySolvable',
        'dateKeyLocal': source.dateKeyLocal,
      },
      RandomSolvableDealSource _ => <String, dynamic>{
        'type': 'randomSolvable',
        'index': source.index,
      },
    };
  }

  static DealSource _decodeDealSource(Map<String, dynamic> json) {
    switch (json['type'] as String) {
      case 'random':
        return RandomDealSource(json['seed'] as int);
      case 'daily':
        return DailyDealSource(json['dateKeyLocal'] as String);
      case 'dailySolvable':
        return DailySolvableDealSource(json['dateKeyLocal'] as String);
      case 'randomSolvable':
        return RandomSolvableDealSource(json['index'] as int);
      case 'solvableLibrary':
        // Backward compatibility for older placeholder saves.
        return RandomSolvableDealSource(json['index'] as int);
      default:
        return RandomDealSource(0);
    }
  }

  static GameAction _decodeAction(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'dealFromStock':
        return DealFromStockAction.fromJson(json);
      case 'moveStack':
        return MoveStackAction.fromJson(json);
      case 'autoCompleteRun':
        return AutoCompleteRunAction.fromJson(json);
      default:
        throw FormatException('Unsupported action type: $type');
    }
  }

  static Map<String, dynamic> _encodeCard(PlayingCard card) {
    return <String, dynamic>{
      'id': card.id,
      'rank': card.rank.name,
      'suit': card.suit.name,
      'faceUp': card.faceUp,
    };
  }

  static PlayingCard _decodeCard(Map<String, dynamic> json) {
    return PlayingCard(
      id: json['id'] as int,
      rank: CardRank.values.byName(json['rank'] as String),
      suit: CardSuit.values.byName(json['suit'] as String),
      faceUp: json['faceUp'] as bool,
    );
  }
}
