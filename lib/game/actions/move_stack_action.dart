import '../model/card.dart';
import '../model/game_state.dart';
import '../model/piles.dart';
import 'game_action.dart';

class MoveStackAction implements GameAction {
  MoveStackAction({
    required this.fromColumn,
    required this.startIndex,
    required this.toColumn,
  });

  final int fromColumn;
  final int startIndex;
  final int toColumn;

  int _movedCount = 0;
  bool _flippedSourceTop = false;

  @override
  GameState apply(GameState state) {
    final columns = state.tableau.columns
        .map((c) => List<PlayingCard>.of(c))
        .toList();
    if (fromColumn < 0 ||
        fromColumn >= columns.length ||
        toColumn < 0 ||
        toColumn >= columns.length) {
      return state;
    }
    if (startIndex < 0 || startIndex >= columns[fromColumn].length) {
      return state;
    }

    final movedStack = columns[fromColumn].sublist(startIndex);
    _movedCount = movedStack.length;
    columns[fromColumn].removeRange(startIndex, columns[fromColumn].length);
    columns[toColumn].addAll(movedStack);

    _flippedSourceTop = false;
    if (columns[fromColumn].isNotEmpty && !columns[fromColumn].last.faceUp) {
      _flippedSourceTop = true;
      columns[fromColumn][columns[fromColumn].length - 1] = columns[fromColumn]
          .last
          .copyWith(faceUp: true);
    }

    return state.copyWith(
      tableau: TableauPiles(columns),
      moves: state.moves + 1,
    );
  }

  @override
  GameState revert(GameState state) {
    if (_movedCount == 0) {
      return state;
    }

    final columns = state.tableau.columns
        .map((c) => List<PlayingCard>.of(c))
        .toList();
    if (columns[toColumn].length < _movedCount) {
      return state;
    }

    final movedBack = columns[toColumn].sublist(
      columns[toColumn].length - _movedCount,
    );
    columns[toColumn].removeRange(
      columns[toColumn].length - _movedCount,
      columns[toColumn].length,
    );
    columns[fromColumn].addAll(movedBack);

    if (_flippedSourceTop && columns[fromColumn].length > _movedCount) {
      final revealIndex = columns[fromColumn].length - _movedCount - 1;
      columns[fromColumn][revealIndex] = columns[fromColumn][revealIndex]
          .copyWith(faceUp: false);
    }

    return state.copyWith(
      tableau: TableauPiles(columns),
      moves: state.moves > 0 ? state.moves - 1 : 0,
    );
  }
}
