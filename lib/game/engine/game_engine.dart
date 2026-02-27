import '../actions/deal_from_stock_action.dart';
import '../actions/game_action.dart';
import '../actions/move_stack_action.dart';
import '../model/card.dart';
import '../model/deal_source.dart';
import '../model/difficulty.dart';
import '../model/game_state.dart';
import '../model/piles.dart';
import '../../utils/clock.dart';
import 'hint_service.dart';
import 'move_validator.dart';

class GameEngine {
  GameEngine({
    Clock? clock,
    MoveValidator? moveValidator,
    HintService? hintService,
  }) : _clock = clock ?? const SystemClock(),
       _moveValidator = moveValidator ?? const MoveValidator(),
       _hintService = hintService ?? const HintService();

  final Clock _clock;
  final MoveValidator _moveValidator;
  final HintService _hintService;
  final List<GameAction> _undoStack = <GameAction>[];
  final List<GameAction> _redoStack = <GameAction>[];

  late GameState _state;
  GameState get state => _state;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void newGame({
    required Difficulty difficulty,
    required DealSource dealSource,
  }) {
    final seed = dealSource.toSeed();
    _state = _buildInitialState(
      seed: seed,
      difficulty: difficulty,
      dealSource: dealSource,
    );
    _undoStack.clear();
    _redoStack.clear();
  }

  void restartSameDeal() {
    _state = _buildInitialState(
      seed: _state.seed,
      difficulty: _state.difficulty,
      dealSource: _state.dealSource,
    );
    _undoStack.clear();
    _redoStack.clear();
  }

  bool dealFromStock() {
    final action = const DealFromStockAction();
    return _applyAction(action);
  }

  bool moveStack(int fromColumn, int startIndex, int toColumn) {
    if (fromColumn < 0 ||
        fromColumn >= _state.tableau.columns.length ||
        toColumn < 0 ||
        toColumn >= _state.tableau.columns.length) {
      return false;
    }
    final from = _state.tableau.columns[fromColumn];
    final to = _state.tableau.columns[toColumn];
    if (!_moveValidator.canMoveStack(
      fromColumnCards: from,
      startIndex: startIndex,
      toColumnCards: to,
    )) {
      return false;
    }
    final action = MoveStackAction(
      fromColumn: fromColumn,
      startIndex: startIndex,
      toColumn: toColumn,
    );
    return _applyAction(action);
  }

  bool undo() {
    if (_undoStack.isEmpty) {
      return false;
    }
    final action = _undoStack.removeLast();
    _state = action.revert(_state);
    _redoStack.add(action);
    return true;
  }

  bool redo() {
    if (_redoStack.isEmpty) {
      return false;
    }
    final action = _redoStack.removeLast();
    _state = action.apply(_state);
    _undoStack.add(action);
    return true;
  }

  String? requestHint() => _hintService.requestHint(_state);

  bool _applyAction(GameAction action) {
    final next = action.apply(_state);
    if (identical(next, _state)) {
      return false;
    }
    if (next == _state) {
      return false;
    }
    _state = next;
    _undoStack.add(action);
    _redoStack.clear();
    return true;
  }

  GameState _buildInitialState({
    required int seed,
    required Difficulty difficulty,
    required DealSource dealSource,
  }) {
    final deck = _buildDeckForDifficulty(difficulty);
    final shuffled = _shuffleDeterministic(deck, seed);

    final columns = List<List<PlayingCard>>.generate(
      10,
      (_) => <PlayingCard>[],
    );
    var cursor = 0;
    for (var col = 0; col < 10; col++) {
      final count = col < 4 ? 6 : 5;
      for (var i = 0; i < count; i++) {
        final isTop = i == count - 1;
        columns[col].add(shuffled[cursor++].copyWith(faceUp: isTop));
      }
    }

    final stock = shuffled
        .sublist(cursor)
        .map((c) => c.copyWith(faceUp: false))
        .toList();
    return GameState(
      tableau: TableauPiles(columns),
      stock: StockPile(stock),
      foundations: const Foundations(completedRuns: 0),
      difficulty: difficulty,
      dealSource: dealSource,
      seed: seed,
      startedAt: _clock.now(),
      moves: 0,
      hintsUsed: 0,
    );
  }

  static List<PlayingCard> _buildDeckForDifficulty(Difficulty difficulty) {
    final allSuits = CardSuit.values;
    final allRanks = CardRank.values;
    final deck = <PlayingCard>[];
    var id = 0;

    for (var i = 0; i < 8; i++) {
      for (final rank in allRanks) {
        CardSuit suit;
        switch (difficulty) {
          case Difficulty.oneSuit:
            suit = CardSuit.spades;
          case Difficulty.twoSuit:
            suit = i.isEven ? CardSuit.spades : CardSuit.hearts;
          case Difficulty.fourSuit:
            suit = allSuits[i % allSuits.length];
        }
        deck.add(PlayingCard(id: id++, rank: rank, suit: suit, faceUp: false));
      }
    }
    return deck;
  }

  static List<PlayingCard> _shuffleDeterministic(
    List<PlayingCard> deck,
    int seed,
  ) {
    final result = List<PlayingCard>.of(deck);
    var state = seed & 0x7fffffff;

    int nextInt(int maxExclusive) {
      state = (1103515245 * state + 12345) & 0x7fffffff;
      return state % maxExclusive;
    }

    for (var i = result.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }

    return result;
  }

  // Test helpers
  static List<PlayingCard> buildDeckForTest(Difficulty difficulty) =>
      _buildDeckForDifficulty(difficulty);
  static List<PlayingCard> shuffleForTest(List<PlayingCard> deck, int seed) =>
      _shuffleDeterministic(deck, seed);
}
