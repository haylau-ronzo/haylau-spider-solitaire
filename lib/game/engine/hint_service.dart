import '../model/card.dart';
import '../model/game_state.dart';
import 'move_validator.dart';

class HintMove {
  const HintMove({
    required this.fromColumn,
    required this.startIndex,
    required this.toColumn,
    required this.length,
    required this.topCardRank,
    required this.topCardSuit,
  });

  final int fromColumn;
  final int startIndex;
  final int toColumn;
  final int length;
  final CardRank topCardRank;
  final CardSuit topCardSuit;
}

class HintService {
  const HintService();

  HintMove? findHintMove(GameState state, MoveValidator validator) {
    _HintCandidate? best;

    for (
      var fromColumn = 0;
      fromColumn < state.tableau.columns.length;
      fromColumn++
    ) {
      final source = state.tableau.columns[fromColumn];
      for (var startIndex = 0; startIndex < source.length; startIndex++) {
        final run = validator.getEffectiveMoveRun(
          state,
          fromColumn,
          startIndex,
        );
        if (run == null) {
          continue;
        }

        final effectiveStart = run.effectiveStartIndex;
        final moved = source.sublist(
          effectiveStart,
          effectiveStart + run.length,
        );
        final firstCard = moved.first;

        for (
          var toColumn = 0;
          toColumn < state.tableau.columns.length;
          toColumn++
        ) {
          if (toColumn == fromColumn) {
            continue;
          }
          if (!validator.canDropRun(state, toColumn, firstCard).isValid) {
            continue;
          }

          final destination = state.tableau.columns[toColumn];
          final ontoNonEmpty = destination.isNotEmpty;
          final sameSuitContinuation =
              destination.isNotEmpty && destination.last.suit == firstCard.suit;
          final uncoversFaceDown =
              effectiveStart > 0 &&
              source[effectiveStart - 1].faceUp == false &&
              effectiveStart + run.length == source.length;

          final candidate = _HintCandidate(
            move: HintMove(
              fromColumn: fromColumn,
              startIndex: effectiveStart,
              toColumn: toColumn,
              length: run.length,
              topCardRank: firstCard.rank,
              topCardSuit: firstCard.suit,
            ),
            uncoversFaceDown: uncoversFaceDown,
            sameSuitContinuation: sameSuitContinuation,
            ontoNonEmpty: ontoNonEmpty,
          );

          if (best == null || candidate.compareTo(best) < 0) {
            best = candidate;
          }
        }
      }
    }

    return best?.move;
  }

  String? requestHint(GameState state, MoveValidator validator) {
    final move = findHintMove(state, validator);
    if (move == null) {
      return null;
    }
    return 'Move ${move.topCardRank.label}${move.topCardSuit.symbol} from '
        '${move.fromColumn + 1} to ${move.toColumn + 1}';
  }
}

class _HintCandidate {
  const _HintCandidate({
    required this.move,
    required this.uncoversFaceDown,
    required this.sameSuitContinuation,
    required this.ontoNonEmpty,
  });

  final HintMove move;
  final bool uncoversFaceDown;
  final bool sameSuitContinuation;
  final bool ontoNonEmpty;

  int compareTo(_HintCandidate other) {
    final a = this;
    final b = other;

    int boolRank(bool value) => value ? 1 : 0;

    final byUncover =
        boolRank(b.uncoversFaceDown) - boolRank(a.uncoversFaceDown);
    if (byUncover != 0) {
      return byUncover;
    }

    final bySuit =
        boolRank(b.sameSuitContinuation) - boolRank(a.sameSuitContinuation);
    if (bySuit != 0) {
      return bySuit;
    }

    final byNonEmpty = boolRank(b.ontoNonEmpty) - boolRank(a.ontoNonEmpty);
    if (byNonEmpty != 0) {
      return byNonEmpty;
    }

    final byLength = b.move.length - a.move.length;
    if (byLength != 0) {
      return byLength;
    }

    final byFrom = a.move.fromColumn - b.move.fromColumn;
    if (byFrom != 0) {
      return byFrom;
    }

    return a.move.toColumn - b.move.toColumn;
  }
}
