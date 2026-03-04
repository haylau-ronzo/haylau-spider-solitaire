import '../actions/auto_complete_run_action.dart';
import '../actions/deal_from_stock_action.dart';
import '../actions/game_action.dart';
import '../actions/move_stack_action.dart';
import '../model/card.dart';
import '../model/deal_source.dart';
import '../model/difficulty.dart';
import '../model/game_state.dart';
import '../model/piles.dart';
import '../persistence/stats_repo.dart';
import '../scoring/score_calculator.dart';
import '../../utils/clock.dart';
import 'hint_service.dart';
import 'move_validator.dart';

class GameEngine {
  static const int progressRevealFaceDownScore = 100;
  static const int progressAutocompleteScore = 50;
  static const int progressSameSuitTailDeltaMultiplier = 10;
  static const int progressCreateEmptyColumnScore = 5;
  static const int progressLateralSwapPenalty = 10;

  GameEngine({
    Clock? clock,
    MoveValidator? moveValidator,
    HintService? hintService,
    StatsRepo? statsRepo,
  }) : _clock = clock ?? const SystemClock(),
       _moveValidator = moveValidator ?? const MoveValidator(),
       _hintService = hintService ?? const HintService(),
       _statsRepo = statsRepo ?? InMemoryStatsRepo();

  final Clock _clock;
  final MoveValidator _moveValidator;
  final HintService _hintService;
  final StatsRepo _statsRepo;
  final List<GameAction> _undoStack = <GameAction>[];
  final List<GameAction> _redoStack = <GameAction>[];
  bool _completionRecorded = false;

  late GameState _state;
  GameState get state => _state;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get isWon => _state.foundations.completedRuns >= 8;
  bool get isGameWon => isWon;

  List<GameAction> get undoStackSnapshot =>
      List<GameAction>.unmodifiable(_undoStack);
  List<GameAction> get redoStackSnapshot =>
      List<GameAction>.unmodifiable(_redoStack);

  int elapsedSeconds({DateTime? at}) {
    final now = at ?? _clock.now();
    final seconds = now.difference(_state.startedAt).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  int computeScore({int? elapsedSeconds}) {
    return calculateScore(
      difficulty: _state.difficulty,
      timeSeconds: elapsedSeconds ?? this.elapsedSeconds(),
      moves: _state.moves,
      undos: _state.undosUsed,
      hints: _state.hintsUsed,
    );
  }

  void newGame({
    required Difficulty difficulty,
    required DealSource dealSource,
  }) {
    final seed = dealSource.toSeed(difficulty: difficulty);
    _state = _buildInitialState(
      seed: seed,
      difficulty: difficulty,
      dealSource: dealSource,
    );
    _undoStack.clear();
    _redoStack.clear();
    _completionRecorded = false;
    _recordGameStarted();
  }

  void restartSameDeal() {
    final nextRestarts = _state.restartsUsed + 1;
    _state = _buildInitialState(
      seed: _state.seed,
      difficulty: _state.difficulty,
      dealSource: _state.dealSource,
    ).copyWith(restartsUsed: nextRestarts);
    _undoStack.clear();
    _redoStack.clear();
    _completionRecorded = false;
  }

  bool dealFromStock() {
    final action = const DealFromStockAction();
    final didDeal = _applyAction(action);
    if (didDeal) {
      _recordMove();
      _applyAutoCompletes();
    }
    return didDeal;
  }

  bool moveStack(int fromColumn, int startIndex, int toColumn) {
    if (fromColumn < 0 ||
        fromColumn >= _state.tableau.columns.length ||
        toColumn < 0 ||
        toColumn >= _state.tableau.columns.length) {
      return false;
    }
    if (fromColumn == toColumn) {
      return false;
    }

    final effectiveRun = _moveValidator.getEffectiveMoveRun(
      _state,
      fromColumn,
      startIndex,
    );
    if (effectiveRun == null) {
      return false;
    }

    final effectiveStartIndex = effectiveRun.effectiveStartIndex;
    final movingCards = _state.tableau.columns[fromColumn].sublist(
      effectiveStartIndex,
      effectiveStartIndex + effectiveRun.length,
    );
    final drop = _moveValidator.canDropRun(_state, toColumn, movingCards.first);
    if (!drop.isValid) {
      return false;
    }

    final source = _state.tableau.columns[fromColumn];
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
    final moved = _applyAction(action);
    if (moved) {
      _recordMove();
      _applyAutoCompletes();
    }
    return moved;
  }

  bool undo() {
    if (_undoStack.isEmpty) {
      return false;
    }
    final action = _undoStack.removeLast();
    _state = action.revert(_state).copyWith(undosUsed: _state.undosUsed + 1);
    _redoStack.add(action);
    _recordUndo();
    _completionRecorded = _state.foundations.completedRuns >= 8;
    return true;
  }

  bool redo() {
    if (_redoStack.isEmpty) {
      return false;
    }
    final action = _redoStack.removeLast();
    _state = action.apply(_state).copyWith(redosUsed: _state.redosUsed + 1);
    _undoStack.add(action);
    _recordRedo();
    if (_state.foundations.completedRuns >= 8 && !_completionRecorded) {
      _recordGameCompleted();
      _completionRecorded = true;
    }
    return true;
  }

  HintMove? findHintMove() {
    return _hintService.findHintMove(_state, _moveValidator);
  }

  HintMove? requestHintMove() {
    _recordHint();
    _state = _state.copyWith(hintsUsed: _state.hintsUsed + 1);
    return findHintMove();
  }

  String? requestHint() {
    _recordHint();
    _state = _state.copyWith(hintsUsed: _state.hintsUsed + 1);
    return _hintService.requestHint(_state, _moveValidator);
  }

  void debugSetDevResultMetrics() {
    final now = _clock.now();
    final metrics = _buildDevMetrics(_state.difficulty, _state.seed);
    _state = _state.copyWith(
      startedAt: now.subtract(Duration(seconds: metrics.timeSeconds)),
      moves: metrics.moves,
      undosUsed: metrics.undos,
      redosUsed: metrics.redos,
      hintsUsed: metrics.hints,
    );
  }

  void debugForceWin() {
    _state = _state.copyWith(
      tableau: TableauPiles(
        List<List<PlayingCard>>.generate(10, (_) => <PlayingCard>[]),
      ),
      stock: StockPile(const <PlayingCard>[]),
      foundations: const Foundations(completedRuns: 8),
    );
    _undoStack.clear();
    _redoStack.clear();
    if (!_completionRecorded) {
      _recordGameCompleted();
      _completionRecorded = true;
    }
  }

  void restoreState(
    GameState state, {
    List<GameAction> undoStack = const <GameAction>[],
    List<GameAction> redoStack = const <GameAction>[],
  }) {
    _state = state;
    _undoStack
      ..clear()
      ..addAll(undoStack);
    _redoStack
      ..clear()
      ..addAll(redoStack);
    _completionRecorded = _state.foundations.completedRuns >= 8;
  }

  ValidationResult canDropRun(int toColumn, PlayingCard firstCard) {
    return _moveValidator.canDropRun(_state, toColumn, firstCard);
  }

  DraggableRun? getEffectiveMoveRun(int fromColumn, int tappedIndex) {
    return _moveValidator.getEffectiveMoveRun(_state, fromColumn, tappedIndex);
  }

  List<int> getLegalDropTargets(PlayingCard runFirstCard) {
    return _moveValidator.getLegalDropTargets(_state, runFirstCard);
  }

  bool isStockDealAvailable({required bool unrestrictedDealRule}) {
    if (_state.stock.cards.length < 10) {
      return false;
    }
    if (unrestrictedDealRule) {
      return true;
    }
    return _state.tableau.columns.every((column) => column.isNotEmpty);
  }

  bool hasAnyValidMoves({required bool unrestrictedDealRule}) {
    if (_hasAnyTableauMove()) {
      return true;
    }
    return isStockDealAvailable(unrestrictedDealRule: unrestrictedDealRule);
  }

  bool hasAnyProgressMoves({required bool unrestrictedDealRule}) {
    if (isStockDealAvailable(unrestrictedDealRule: unrestrictedDealRule)) {
      return true;
    }
    return bestProgressScore() > 0;
  }

  bool hasAnyUsefulMoves({required bool unrestrictedDealRule}) {
    return hasAnyProgressMoves(unrestrictedDealRule: unrestrictedDealRule);
  }

  int bestProgressScore() {
    var best = 0;
    for (final move in _buildLegalMoves()) {
      final score = _progressScoreForMove(move);
      if (score > best) {
        best = score;
      }
    }
    return best;
  }

  List<MovableRunHint> getAllMovableRuns({int maxCount = 12}) {
    final runs = <MovableRunHint>[];

    for (
      var fromColumn = 0;
      fromColumn < _state.tableau.columns.length;
      fromColumn++
    ) {
      final source = _state.tableau.columns[fromColumn];
      for (var startIndex = 0; startIndex < source.length; startIndex++) {
        final run = _moveValidator.getEffectiveMoveRun(
          _state,
          fromColumn,
          startIndex,
        );
        if (run == null || run.effectiveStartIndex != startIndex) {
          continue;
        }
        final revealsFaceDown =
            startIndex > 0 &&
            source[startIndex - 1].faceUp == false &&
            startIndex + run.length == source.length;
        runs.add(
          MovableRunHint(
            fromColumn: fromColumn,
            startIndex: startIndex,
            length: run.length,
            revealsFaceDown: revealsFaceDown,
          ),
        );
      }
    }

    runs.sort((a, b) {
      final revealCompare =
          (b.revealsFaceDown ? 1 : 0) - (a.revealsFaceDown ? 1 : 0);
      if (revealCompare != 0) {
        return revealCompare;
      }
      final byLength = b.length - a.length;
      if (byLength != 0) {
        return byLength;
      }
      final byFrom = a.fromColumn - b.fromColumn;
      if (byFrom != 0) {
        return byFrom;
      }
      return a.startIndex - b.startIndex;
    });

    if (maxCount > 0 && runs.length > maxCount) {
      return runs.sublist(0, maxCount);
    }
    return runs;
  }

  List<MovableRunHint> requestHintRuns({int maxCount = 1}) {
    _recordHint();
    _state = _state.copyWith(hintsUsed: _state.hintsUsed + 1);
    final best = getBestProgressMove();
    if (best == null) {
      return const <MovableRunHint>[];
    }
    return <MovableRunHint>[best];
  }

  MovableRunHint? getBestProgressMove() {
    _LegalMoveOpportunity? bestMove;
    var bestScore = 0;

    for (final move in _buildLegalMoves()) {
      final score = _progressScoreForMove(move);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      } else if (score == bestScore && bestMove != null && score > 0) {
        if (_compareMoveTieBreak(move, bestMove) < 0) {
          bestMove = move;
        }
      }
    }

    if (bestMove == null || bestScore <= 0) {
      return null;
    }

    return MovableRunHint(
      fromColumn: bestMove.fromColumn,
      startIndex: bestMove.startIndex,
      length: bestMove.length,
      revealsFaceDown: bestMove.revealsFaceDown,
    );
  }

  List<MovableRunHint> getUsefulMovableRuns({int maxCount = 12}) {
    final bestByRun = <String, _LegalMoveOpportunity>{};
    final bestScoreByRun = <String, int>{};

    for (final move in _buildLegalMoves()) {
      final score = _progressScoreForMove(move);
      if (score <= 0) {
        continue;
      }

      final key = '${move.fromColumn}:${move.startIndex}:${move.length}';
      final existing = bestByRun[key];
      final existingScore = bestScoreByRun[key] ?? -1;
      if (existing == null ||
          score > existingScore ||
          (score == existingScore &&
              _compareMoveTieBreak(move, existing) < 0)) {
        bestByRun[key] = move;
        bestScoreByRun[key] = score;
      }
    }

    final scoredMoves = bestByRun.values.toList()
      ..sort((a, b) {
        final aKey = '${a.fromColumn}:${a.startIndex}:${a.length}';
        final bKey = '${b.fromColumn}:${b.startIndex}:${b.length}';
        final scoreDiff =
            (bestScoreByRun[bKey] ?? 0) - (bestScoreByRun[aKey] ?? 0);
        if (scoreDiff != 0) {
          return scoreDiff;
        }
        return _compareMoveTieBreak(a, b);
      });

    final runs = scoredMoves
        .map(
          (move) => MovableRunHint(
            fromColumn: move.fromColumn,
            startIndex: move.startIndex,
            length: move.length,
            revealsFaceDown: move.revealsFaceDown,
          ),
        )
        .toList(growable: false);
    if (maxCount > 0 && runs.length > maxCount) {
      return runs.sublist(0, maxCount);
    }
    return runs;
  }

  bool _hasAnyTableauMove() {
    return _buildLegalMoves().isNotEmpty;
  }

  List<_LegalMoveOpportunity> _buildLegalMoves() {
    final moves = <_LegalMoveOpportunity>[];

    for (
      var fromColumn = 0;
      fromColumn < _state.tableau.columns.length;
      fromColumn++
    ) {
      final source = _state.tableau.columns[fromColumn];
      for (var startIndex = 0; startIndex < source.length; startIndex++) {
        final run = _moveValidator.getEffectiveMoveRun(
          _state,
          fromColumn,
          startIndex,
        );
        if (run == null) {
          continue;
        }

        final effectiveStart = run.effectiveStartIndex;
        final movedCards = source.sublist(
          effectiveStart,
          effectiveStart + run.length,
        );
        final firstCard = movedCards.first;
        final revealsFaceDown =
            effectiveStart > 0 &&
            source[effectiveStart - 1].faceUp == false &&
            effectiveStart + run.length == source.length;

        for (
          var toColumn = 0;
          toColumn < _state.tableau.columns.length;
          toColumn++
        ) {
          if (toColumn == fromColumn) {
            continue;
          }
          if (!_moveValidator.canDropRun(_state, toColumn, firstCard).isValid) {
            continue;
          }

          final destination = _state.tableau.columns[toColumn];
          final sameSuitTailIncrease = _state.difficulty == Difficulty.oneSuit
              ? 0
              : (_tailSameSuitRunLength(
                          List<PlayingCard>.of(destination)..addAll(movedCards),
                        ) -
                        _tailSameSuitRunLength(destination))
                    .clamp(0, 13);

          final triggersAutocomplete = _doesMoveTriggerAutocomplete(
            fromColumn: fromColumn,
            startIndex: effectiveStart,
            toColumn: toColumn,
            movedCards: movedCards,
          );
          final createsEmptySourceColumn = effectiveStart == 0;
          final lateralSameRankSwap = _isLateralSameRankSwap(
            fromColumn: fromColumn,
            toColumn: toColumn,
            movedCards: movedCards,
            startIndex: effectiveStart,
          );

          moves.add(
            _LegalMoveOpportunity(
              fromColumn: fromColumn,
              startIndex: effectiveStart,
              toColumn: toColumn,
              length: run.length,
              revealsFaceDown: revealsFaceDown,
              sameSuitTailIncrease: sameSuitTailIncrease,
              triggersAutocomplete: triggersAutocomplete,
              createsEmptySourceColumn: createsEmptySourceColumn,
              lateralSameRankSwap: lateralSameRankSwap,
            ),
          );
        }
      }
    }

    return moves;
  }

  int _tailSameSuitRunLength(List<PlayingCard> cards) {
    if (cards.isEmpty) {
      return 0;
    }
    var length = 1;
    for (var i = cards.length - 1; i > 0; i--) {
      final lower = cards[i];
      final upper = cards[i - 1];
      if (upper.suit != lower.suit ||
          upper.rank.value != lower.rank.value + 1) {
        break;
      }
      length++;
    }
    return length;
  }

  bool _doesMoveTriggerAutocomplete({
    required int fromColumn,
    required int startIndex,
    required int toColumn,
    required List<PlayingCard> movedCards,
  }) {
    final simulatedColumns = _state.tableau.columns
        .map((column) => List<PlayingCard>.of(column))
        .toList();

    final source = simulatedColumns[fromColumn];
    source.removeRange(startIndex, source.length);
    if (source.isNotEmpty && source.last.faceUp == false) {
      source[source.length - 1] = source.last.copyWith(faceUp: true);
    }

    simulatedColumns[toColumn].addAll(movedCards);
    final simulatedState = _state.copyWith(
      tableau: TableauPiles(simulatedColumns),
    );

    for (
      var column = 0;
      column < simulatedState.tableau.columns.length;
      column++
    ) {
      if (_moveValidator.detectCompleteRunAtEnd(simulatedState, column) !=
          null) {
        return true;
      }
    }

    return false;
  }

  int _progressScoreForMove(_LegalMoveOpportunity move) {
    if (move.lateralSameRankSwap &&
        !move.revealsFaceDown &&
        !move.triggersAutocomplete) {
      return 0;
    }

    var score = 0;
    if (move.revealsFaceDown) {
      score += progressRevealFaceDownScore;
    }
    if (move.triggersAutocomplete) {
      score += progressAutocompleteScore;
    }
    if (_state.difficulty != Difficulty.oneSuit) {
      score += move.sameSuitTailIncrease * progressSameSuitTailDeltaMultiplier;
    }
    if (move.lateralSameRankSwap) {
      score -= progressLateralSwapPenalty;
    }
    return score < 0 ? 0 : score;
  }

  int _compareMoveTieBreak(_LegalMoveOpportunity a, _LegalMoveOpportunity b) {
    int rank(bool v) => v ? 1 : 0;

    final reveal = rank(b.revealsFaceDown) - rank(a.revealsFaceDown);
    if (reveal != 0) {
      return reveal;
    }
    final auto = rank(b.triggersAutocomplete) - rank(a.triggersAutocomplete);
    if (auto != 0) {
      return auto;
    }
    final suit = b.sameSuitTailIncrease - a.sameSuitTailIncrease;
    if (suit != 0) {
      return suit;
    }
    final empty =
        rank(b.createsEmptySourceColumn) - rank(a.createsEmptySourceColumn);
    if (empty != 0) {
      return empty;
    }
    final byLength = b.length - a.length;
    if (byLength != 0) {
      return byLength;
    }
    final byFrom = a.fromColumn - b.fromColumn;
    if (byFrom != 0) {
      return byFrom;
    }
    return a.toColumn - b.toColumn;
  }

  bool _isLateralSameRankSwap({
    required int fromColumn,
    required int toColumn,
    required List<PlayingCard> movedCards,
    required int startIndex,
  }) {
    final destination = _state.tableau.columns[toColumn];
    if (destination.isEmpty) {
      return false;
    }

    final destinationTop = destination.last;
    var hasAlternativeSameRank = false;
    for (var col = 0; col < _state.tableau.columns.length; col++) {
      if (col == fromColumn || col == toColumn) {
        continue;
      }
      if (!_moveValidator.canDropRun(_state, col, movedCards.first).isValid) {
        continue;
      }
      final candidate = _state.tableau.columns[col];
      if (candidate.isNotEmpty && candidate.last.rank == destinationTop.rank) {
        hasAlternativeSameRank = true;
        break;
      }
    }
    if (!hasAlternativeSameRank) {
      return false;
    }

    final simulatedColumns = _state.tableau.columns
        .map((column) => List<PlayingCard>.of(column))
        .toList();
    final simulatedSource = simulatedColumns[fromColumn];
    final simulatedDestination = simulatedColumns[toColumn];
    final destinationStart = simulatedDestination.length;

    simulatedSource.removeRange(startIndex, simulatedSource.length);
    if (simulatedSource.isNotEmpty && simulatedSource.last.faceUp == false) {
      simulatedSource[simulatedSource.length - 1] = simulatedSource.last
          .copyWith(faceUp: true);
    }
    simulatedDestination.addAll(movedCards);

    final simulated = _state.copyWith(tableau: TableauPiles(simulatedColumns));
    final movedRun = _moveValidator.getEffectiveMoveRun(
      simulated,
      toColumn,
      destinationStart,
    );
    if (movedRun == null || movedRun.effectiveStartIndex != destinationStart) {
      return false;
    }
    return _moveValidator
        .canDropRun(simulated, fromColumn, movedCards.first)
        .isValid;
  }

  int evaluateDestinationRunLengthAfterMove({
    required int toColumn,
    required List<PlayingCard> movedCards,
  }) {
    if (toColumn < 0 || toColumn >= _state.tableau.columns.length) {
      return 0;
    }
    return _moveValidator.evaluateDestinationRunLengthAfterMove(
      destinationColumn: _state.tableau.columns[toColumn],
      movedCards: movedCards,
    );
  }

  int? chooseAutoDestination({
    required int fromColumn,
    required List<PlayingCard> movedCards,
    required List<int> legalTargets,
  }) {
    if (movedCards.isEmpty) {
      return null;
    }

    final firstCard = movedCards.first;
    final candidates = legalTargets.where((col) => col != fromColumn).toList();
    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final aColumn = _state.tableau.columns[a];
      final bColumn = _state.tableau.columns[b];

      final aSuitMatch =
          aColumn.isNotEmpty && aColumn.last.suit == firstCard.suit ? 1 : 0;
      final bSuitMatch =
          bColumn.isNotEmpty && bColumn.last.suit == firstCard.suit ? 1 : 0;
      if (aSuitMatch != bSuitMatch) {
        return bSuitMatch.compareTo(aSuitMatch);
      }

      final aNonEmpty = aColumn.isNotEmpty ? 1 : 0;
      final bNonEmpty = bColumn.isNotEmpty ? 1 : 0;
      if (aNonEmpty != bNonEmpty) {
        return bNonEmpty.compareTo(aNonEmpty);
      }

      final aRunLength = evaluateDestinationRunLengthAfterMove(
        toColumn: a,
        movedCards: movedCards,
      );
      final bRunLength = evaluateDestinationRunLengthAfterMove(
        toColumn: b,
        movedCards: movedCards,
      );
      if (aRunLength != bRunLength) {
        return bRunLength.compareTo(aRunLength);
      }

      return a.compareTo(b);
    });

    return candidates.first;
  }

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

  void _applyAutoCompletes() {
    var foundAny = true;
    while (foundAny) {
      foundAny = false;
      for (var column = 0; column < _state.tableau.columns.length; column++) {
        final startIndex = _moveValidator.detectCompleteRunAtEnd(
          _state,
          column,
        );
        if (startIndex == null) {
          continue;
        }
        final removed = List<PlayingCard>.of(
          _state.tableau.columns[column].sublist(startIndex),
        );
        final source = _state.tableau.columns[column];
        final flipsExposedCard =
            startIndex > 0 &&
            source[startIndex - 1].faceUp == false &&
            startIndex + removed.length == source.length;
        final action = AutoCompleteRunAction(
          columnIndex: column,
          startIndex: startIndex,
          removedCards: removed,
          flippedExposedCardOnApply: flipsExposedCard,
        );
        if (_applyAction(action)) {
          foundAny = true;
          if (_state.foundations.completedRuns >= 8 && !_completionRecorded) {
            _recordGameCompleted();
            _completionRecorded = true;
          }
        }
      }
    }
  }

  void _recordGameStarted() {
    final current = _statsRepo.current();
    _statsRepo.save(
      current.copyWith(totalGamesStarted: current.totalGamesStarted + 1),
    );
  }

  void _recordGameCompleted() {
    final current = _statsRepo.current();
    final wins = Map<Difficulty, int>.from(current.winsByDifficulty);
    wins[_state.difficulty] = (wins[_state.difficulty] ?? 0) + 1;

    final elapsed = elapsedSeconds();
    final score = computeScore(elapsedSeconds: elapsed);

    final bestScores = Map<Difficulty, int>.from(current.bestScoreByDifficulty);
    final existingBestScore = bestScores[_state.difficulty];
    if (existingBestScore == null || score > existingBestScore) {
      bestScores[_state.difficulty] = score;
    }

    final bestTimes = Map<Difficulty, int>.from(current.bestTimeByDifficulty);
    final existingBestTime = bestTimes[_state.difficulty];
    if (existingBestTime == null || elapsed < existingBestTime) {
      bestTimes[_state.difficulty] = elapsed;
    }

    _statsRepo.save(
      current.copyWith(
        lifetimeTotalScore: current.lifetimeTotalScore + score,
        totalGamesCompleted: current.totalGamesCompleted + 1,
        winsByDifficulty: wins,
        bestScoreByDifficulty: bestScores,
        bestTimeByDifficulty: bestTimes,
      ),
    );
  }

  void _recordMove() {
    final current = _statsRepo.current();
    _statsRepo.save(current.copyWith(totalMoves: current.totalMoves + 1));
  }

  void _recordUndo() {
    final current = _statsRepo.current();
    _statsRepo.save(current.copyWith(totalUndos: current.totalUndos + 1));
  }

  void _recordRedo() {
    final current = _statsRepo.current();
    _statsRepo.save(current.copyWith(totalRedos: current.totalRedos + 1));
  }

  void _recordHint() {
    final current = _statsRepo.current();
    _statsRepo.save(current.copyWith(totalHints: current.totalHints + 1));
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
      undosUsed: 0,
      redosUsed: 0,
      restartsUsed: 0,
    );
  }

  _DevMetrics _buildDevMetrics(Difficulty difficulty, int seed) {
    switch (difficulty) {
      case Difficulty.oneSuit:
        final undos = _deterministicInRange(seed, 31, 0, 5);
        return _DevMetrics(
          timeSeconds: _deterministicInRange(seed, 11, 300, 900),
          moves: _deterministicInRange(seed, 21, 120, 220),
          undos: undos,
          redos: _deterministicInRange(seed, 41, 0, undos),
          hints: _deterministicInRange(seed, 51, 0, 2),
        );
      case Difficulty.twoSuit:
        final undos = _deterministicInRange(seed, 31, 2, 10);
        return _DevMetrics(
          timeSeconds: _deterministicInRange(seed, 11, 600, 1200),
          moves: _deterministicInRange(seed, 21, 200, 350),
          undos: undos,
          redos: _deterministicInRange(seed, 41, 0, undos),
          hints: _deterministicInRange(seed, 51, 0, 3),
        );
      case Difficulty.fourSuit:
        final undos = _deterministicInRange(seed, 31, 5, 20);
        return _DevMetrics(
          timeSeconds: _deterministicInRange(seed, 11, 900, 2100),
          moves: _deterministicInRange(seed, 21, 300, 550),
          undos: undos,
          redos: _deterministicInRange(seed, 41, 0, undos),
          hints: _deterministicInRange(seed, 51, 0, 5),
        );
    }
  }

  int _deterministicInRange(int seed, int salt, int min, int max) {
    final span = max - min;
    if (span <= 0) {
      return min;
    }
    var state = (seed ^ (salt * 2654435761)) & 0x7fffffff;
    state = (1103515245 * state + 12345) & 0x7fffffff;
    return min + (state % (span + 1));
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

  static List<PlayingCard> buildDeckForTest(Difficulty difficulty) =>
      _buildDeckForDifficulty(difficulty);

  static List<PlayingCard> shuffleForTest(List<PlayingCard> deck, int seed) =>
      _shuffleDeterministic(deck, seed);
}

class MovableRunHint {
  const MovableRunHint({
    required this.fromColumn,
    required this.startIndex,
    required this.length,
    required this.revealsFaceDown,
  });

  final int fromColumn;
  final int startIndex;
  final int length;
  final bool revealsFaceDown;
}

class _LegalMoveOpportunity {
  const _LegalMoveOpportunity({
    required this.fromColumn,
    required this.startIndex,
    required this.toColumn,
    required this.length,
    required this.revealsFaceDown,
    required this.sameSuitTailIncrease,
    required this.triggersAutocomplete,
    required this.createsEmptySourceColumn,
    required this.lateralSameRankSwap,
  });

  final int fromColumn;
  final int startIndex;
  final int toColumn;
  final int length;
  final bool revealsFaceDown;
  final int sameSuitTailIncrease;
  final bool triggersAutocomplete;
  final bool createsEmptySourceColumn;
  final bool lateralSameRankSwap;
}

class _DevMetrics {
  const _DevMetrics({
    required this.timeSeconds,
    required this.moves,
    required this.undos,
    required this.redos,
    required this.hints,
  });

  final int timeSeconds;
  final int moves;
  final int undos;
  final int redos;
  final int hints;
}
