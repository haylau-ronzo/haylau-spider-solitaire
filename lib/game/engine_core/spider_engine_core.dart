import '../actions/auto_complete_run_action.dart';
import '../actions/deal_from_stock_action.dart';
import '../actions/move_stack_action.dart';
import '../engine/move_validator.dart';
import '../model/card.dart';
import '../model/deal_source.dart';
import '../model/difficulty.dart';
import '../model/game_state.dart';
import '../model/piles.dart';
import '../solvable/solvable_solution_step.dart';

class CoreMoveResult {
  const CoreMoveResult({
    required this.didMove,
    required this.state,
    required this.failureReason,
    required this.effectiveStartIndex,
    required this.movedLength,
  });

  final bool didMove;
  final GameState state;
  final String? failureReason;
  final int? effectiveStartIndex;
  final int? movedLength;
}

class SpiderEngineCore {
  static const MoveValidator _defaultValidator = MoveValidator();

  static GameState buildInitialState({
    required int seed,
    required Difficulty difficulty,
    DealSource? dealSource,
    DateTime? startedAt,
  }) {
    final deck = buildDeckForDifficulty(difficulty);
    final shuffled = shuffleDeterministic(deck, seed);

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
      dealSource: dealSource ?? RandomDealSource(seed),
      seed: seed,
      startedAt: startedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      moves: 0,
      hintsUsed: 0,
      undosUsed: 0,
      redosUsed: 0,
      restartsUsed: 0,
    );
  }

  static bool canDealFromStock(
    GameState state, {
    required bool unrestrictedDealRule,
  }) {
    if (state.stock.cards.length < 10) {
      return false;
    }
    if (unrestrictedDealRule) {
      return true;
    }
    return state.tableau.columns.every((column) => column.isNotEmpty);
  }

  static GameState? tryDealFromStock(
    GameState state, {
    required bool unrestrictedDealRule,
    MoveValidator validator = _defaultValidator,
  }) {
    if (!canDealFromStock(state, unrestrictedDealRule: unrestrictedDealRule)) {
      return null;
    }
    final dealt = const DealFromStockAction().apply(state);
    if (dealt == state) {
      return null;
    }
    return applyAutoCompletes(dealt, validator: validator);
  }

  static CoreMoveResult tryMoveStack(
    GameState state, {
    required int fromColumn,
    required int startIndex,
    required int toColumn,
    MoveValidator validator = _defaultValidator,
  }) {
    if (fromColumn < 0 ||
        fromColumn >= state.tableau.columns.length ||
        toColumn < 0 ||
        toColumn >= state.tableau.columns.length) {
      return CoreMoveResult(
        didMove: false,
        state: state,
        failureReason: 'invalid column',
        effectiveStartIndex: null,
        movedLength: null,
      );
    }
    if (fromColumn == toColumn) {
      return CoreMoveResult(
        didMove: false,
        state: state,
        failureReason: 'source and destination are the same',
        effectiveStartIndex: null,
        movedLength: null,
      );
    }

    final effectiveRun = validator.getEffectiveMoveRun(
      state,
      fromColumn,
      startIndex,
    );
    if (effectiveRun == null) {
      return CoreMoveResult(
        didMove: false,
        state: state,
        failureReason: 'run invalid',
        effectiveStartIndex: null,
        movedLength: null,
      );
    }

    final effectiveStartIndex = effectiveRun.effectiveStartIndex;
    final movingCards = state.tableau.columns[fromColumn].sublist(
      effectiveStartIndex,
      effectiveStartIndex + effectiveRun.length,
    );
    final drop = validator.canDropRun(state, toColumn, movingCards.first);
    if (!drop.isValid) {
      return CoreMoveResult(
        didMove: false,
        state: state,
        failureReason: drop.reason ?? 'drop invalid',
        effectiveStartIndex: effectiveStartIndex,
        movedLength: effectiveRun.length,
      );
    }

    final source = state.tableau.columns[fromColumn];
    final exposesFacedownTop =
        effectiveStartIndex > 0 &&
        source[effectiveStartIndex - 1].faceUp == false &&
        effectiveStartIndex + movingCards.length == source.length;

    final action = MoveStackAction(
      fromColumn: fromColumn,
      toColumn: toColumn,
      startIndex: effectiveStartIndex,
      movedCards: movingCards,
      flippedSourceCardOnApply: exposesFacedownTop,
    );
    final moved = action.apply(state);
    if (moved == state) {
      return CoreMoveResult(
        didMove: false,
        state: state,
        failureReason: 'move action rejected',
        effectiveStartIndex: effectiveStartIndex,
        movedLength: effectiveRun.length,
      );
    }

    final normalized = applyAutoCompletes(moved, validator: validator);
    return CoreMoveResult(
      didMove: true,
      state: normalized,
      failureReason: null,
      effectiveStartIndex: effectiveStartIndex,
      movedLength: effectiveRun.length,
    );
  }

  static GameState applyAutoCompletes(
    GameState state, {
    MoveValidator validator = _defaultValidator,
  }) {
    var current = state;
    var changed = true;

    while (changed) {
      changed = false;
      for (var column = 0; column < current.tableau.columns.length; column++) {
        final startIndex = validator.detectCompleteRunAtEnd(current, column);
        if (startIndex == null) {
          continue;
        }

        final removedCards = current.tableau.columns[column].sublist(
          startIndex,
        );
        final source = current.tableau.columns[column];
        final flipsExposedCard =
            startIndex > 0 &&
            source[startIndex - 1].faceUp == false &&
            startIndex + removedCards.length == source.length;

        final action = AutoCompleteRunAction(
          columnIndex: column,
          startIndex: startIndex,
          removedCards: removedCards,
          flippedExposedCardOnApply: flipsExposedCard,
        );

        final next = action.apply(current);
        if (next != current) {
          current = next;
          changed = true;
        }
      }
    }

    return current;
  }

  static String? replayValidationError({
    required int seed,
    required Difficulty difficulty,
    required List<SolutionStepDto> steps,
    required bool unrestrictedDealRule,
    MoveValidator validator = _defaultValidator,
  }) {
    var state = buildInitialState(seed: seed, difficulty: difficulty);
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (step.isDeal) {
        final dealt = tryDealFromStock(
          state,
          unrestrictedDealRule: unrestrictedDealRule,
          validator: validator,
        );
        if (dealt == null) {
          return 'step ${i + 1}: dealFromStock rejected';
        }
        state = dealt;
        continue;
      }

      if (!step.isMove ||
          step.fromColumn == null ||
          step.toColumn == null ||
          step.startIndex == null) {
        return 'step ${i + 1}: invalid move dto';
      }

      final move = tryMoveStack(
        state,
        fromColumn: step.fromColumn!,
        startIndex: step.startIndex!,
        toColumn: step.toColumn!,
        validator: validator,
      );
      if (!move.didMove) {
        return 'step ${i + 1}: moveStack rejected from=${step.fromColumn} '
            'to=${step.toColumn} start=${step.startIndex} '
            'reason=${move.failureReason ?? 'unknown'}';
      }

      if (step.movedLength != null && move.movedLength != step.movedLength) {
        return 'step ${i + 1}: movedLength mismatch '
            'expected=${step.movedLength} actual=${move.movedLength}';
      }

      state = move.state;
    }
    return null;
  }

  static List<PlayingCard> buildDeckForDifficulty(Difficulty difficulty) {
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

  static List<PlayingCard> shuffleDeterministic(
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
}
