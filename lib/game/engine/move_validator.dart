import '../model/card.dart';
import '../model/difficulty.dart';
import '../model/game_state.dart';

class ValidationResult {
  const ValidationResult({required this.isValid, this.reason});

  final bool isValid;
  final String? reason;
}

class DraggableRun {
  const DraggableRun({required this.effectiveStartIndex, required this.length});

  final int effectiveStartIndex;
  final int length;
}

class MoveValidator {
  const MoveValidator();

  DraggableRun? getEffectiveMoveRun(
    GameState state,
    int fromColumn,
    int tappedIndex,
  ) {
    if (fromColumn < 0 || fromColumn >= state.tableau.columns.length) {
      return null;
    }
    final cards = state.tableau.columns[fromColumn];
    if (tappedIndex < 0 || tappedIndex >= cards.length) {
      return null;
    }
    if (!cards[tappedIndex].faceUp) {
      return null;
    }

    final tail = cards.sublist(tappedIndex);
    final isBottomCard = tappedIndex == cards.length - 1;
    final tailIsMovable = _isValidMovableTail(state.difficulty, tail);

    if (!tailIsMovable) {
      if (!isBottomCard) {
        return null;
      }
      return DraggableRun(effectiveStartIndex: tappedIndex, length: 1);
    }

    return DraggableRun(effectiveStartIndex: tappedIndex, length: tail.length);
  }

  DraggableRun? getDraggableRun(
    GameState state,
    int fromColumn,
    int startIndex,
  ) {
    return getEffectiveMoveRun(state, fromColumn, startIndex);
  }

  ValidationResult canPickUpRun(
    GameState state,
    int fromColumn,
    int startIndex,
  ) {
    if (fromColumn < 0 || fromColumn >= state.tableau.columns.length) {
      return const ValidationResult(
        isValid: false,
        reason: 'Invalid source column.',
      );
    }
    final cards = state.tableau.columns[fromColumn];
    if (startIndex < 0 || startIndex >= cards.length) {
      return const ValidationResult(
        isValid: false,
        reason: 'Invalid card index.',
      );
    }

    final runInfo = getEffectiveMoveRun(state, fromColumn, startIndex);
    if (runInfo == null) {
      return const ValidationResult(
        isValid: false,
        reason: 'Only complete movable tails can be picked up.',
      );
    }

    final runLength = runInfo.length;
    if (runLength <= 0) {
      return const ValidationResult(isValid: false, reason: 'Invalid run.');
    }

    return const ValidationResult(isValid: true);
  }

  List<int> getLegalDropTargets(GameState state, PlayingCard runFirstCard) {
    final targets = <int>[];
    for (var i = 0; i < state.tableau.columns.length; i++) {
      if (canDropRun(state, i, runFirstCard).isValid) {
        targets.add(i);
      }
    }
    return targets;
  }

  List<int> getValidDropTargets(GameState state, PlayingCard runFirstCard) {
    return getLegalDropTargets(state, runFirstCard);
  }

  ValidationResult canDropRun(
    GameState state,
    int toColumn,
    PlayingCard firstCardOfRun,
  ) {
    if (toColumn < 0 || toColumn >= state.tableau.columns.length) {
      return const ValidationResult(
        isValid: false,
        reason: 'Invalid destination column.',
      );
    }

    final destination = state.tableau.columns[toColumn];
    if (destination.isEmpty) {
      return const ValidationResult(isValid: true);
    }

    final target = destination.last;
    if (!target.faceUp) {
      return const ValidationResult(
        isValid: false,
        reason: 'Destination top card must be face-up.',
      );
    }

    final isLegal = target.rank.value == firstCardOfRun.rank.value + 1;
    return ValidationResult(
      isValid: isLegal,
      reason: isLegal ? null : 'Destination rank must be one higher.',
    );
  }

  int evaluateDestinationRunLengthAfterMove({
    required List<PlayingCard> destinationColumn,
    required List<PlayingCard> movedCards,
  }) {
    final merged = List<PlayingCard>.of(destinationColumn)..addAll(movedCards);
    if (merged.isEmpty) {
      return 0;
    }

    var runLength = 1;
    for (var i = merged.length - 1; i > 0; i--) {
      final lower = merged[i];
      final upper = merged[i - 1];
      final sameSuit = lower.suit == upper.suit;
      final descending = upper.rank.value == lower.rank.value + 1;
      if (!sameSuit || !descending) {
        break;
      }
      runLength++;
    }
    return runLength;
  }

  List<int> getMovableRunStartIndices(GameState state, int fromColumn) {
    if (fromColumn < 0 || fromColumn >= state.tableau.columns.length) {
      return const <int>[];
    }
    final cards = state.tableau.columns[fromColumn];
    final indices = <int>[];
    for (var i = 0; i < cards.length; i++) {
      final result = canPickUpRun(state, fromColumn, i);
      if (result.isValid) {
        indices.add(i);
      }
    }
    return indices;
  }

  int? detectCompleteRunAtEnd(GameState state, int columnIndex) {
    if (columnIndex < 0 || columnIndex >= state.tableau.columns.length) {
      return null;
    }

    final cards = state.tableau.columns[columnIndex];
    if (cards.length < 13) {
      return null;
    }
    final start = cards.length - 13;
    final run = cards.sublist(start);
    if (run.any((card) => !card.faceUp)) {
      return null;
    }
    if (run.first.rank != CardRank.king || run.last.rank != CardRank.ace) {
      return null;
    }
    for (var i = 0; i < run.length - 1; i++) {
      if (run[i].rank.value != run[i + 1].rank.value + 1) {
        return null;
      }
    }

    if (state.difficulty == Difficulty.oneSuit) {
      return start;
    }

    final suit = run.first.suit;
    if (run.every((card) => card.suit == suit)) {
      return start;
    }
    return null;
  }

  bool _isValidMovableTail(Difficulty difficulty, List<PlayingCard> tail) {
    if (tail.isEmpty) {
      return false;
    }
    if (tail.any((card) => !card.faceUp)) {
      return false;
    }

    for (var i = 0; i < tail.length - 1; i++) {
      final current = tail[i];
      final next = tail[i + 1];
      final descending = current.rank.value == next.rank.value + 1;
      if (!descending) {
        return false;
      }
      if (difficulty != Difficulty.oneSuit && current.suit != next.suit) {
        return false;
      }
    }
    return true;
  }
}
