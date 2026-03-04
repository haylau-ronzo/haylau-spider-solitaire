import '../model/card.dart';
import '../model/game_state.dart';
import '../model/piles.dart';
import 'game_action.dart';

class AutoCompleteRunAction implements GameAction {
  const AutoCompleteRunAction({
    required this.columnIndex,
    required this.startIndex,
    required this.removedCards,
    required this.flippedExposedCardOnApply,
  });

  final int columnIndex;
  final int startIndex;
  final List<PlayingCard> removedCards;
  final bool flippedExposedCardOnApply;

  @override
  String get type => 'autoCompleteRun';

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'payload': <String, dynamic>{
        'columnIndex': columnIndex,
        'startIndex': startIndex,
        'removedCards': removedCards.map(_encodeCard).toList(),
        'flippedExposedCardOnApply': flippedExposedCardOnApply,
      },
    };
  }

  static AutoCompleteRunAction fromJson(Map<String, dynamic> json) {
    final actionType = json['type'] as String?;
    if (actionType != 'autoCompleteRun') {
      throw FormatException('Invalid action type for AutoCompleteRunAction.');
    }

    final payload = json['payload'] as Map<String, dynamic>?;
    if (payload == null) {
      throw FormatException('Missing autoCompleteRun payload.');
    }

    return AutoCompleteRunAction(
      columnIndex: payload['columnIndex'] as int,
      startIndex: payload['startIndex'] as int,
      removedCards: (payload['removedCards'] as List<dynamic>)
          .map((card) => _decodeCard(card as Map<String, dynamic>))
          .toList(),
      flippedExposedCardOnApply: payload['flippedExposedCardOnApply'] as bool,
    );
  }

  @override
  GameState apply(GameState state) {
    final columns = state.tableau.columns
        .map((column) => List<PlayingCard>.of(column))
        .toList();
    if (columnIndex < 0 || columnIndex >= columns.length) {
      return state;
    }
    final column = columns[columnIndex];
    if (startIndex < 0 || startIndex + removedCards.length > column.length) {
      return state;
    }
    final slice = column.sublist(startIndex, startIndex + removedCards.length);
    if (!_sameCardIds(slice, removedCards)) {
      return state;
    }

    column.removeRange(startIndex, startIndex + removedCards.length);
    if (flippedExposedCardOnApply && column.isNotEmpty) {
      final topIndex = column.length - 1;
      column[topIndex] = column[topIndex].copyWith(faceUp: true);
    }

    return state.copyWith(
      tableau: TableauPiles(columns),
      foundations: state.foundations.copyWith(
        completedRuns: state.foundations.completedRuns + 1,
      ),
    );
  }

  @override
  GameState revert(GameState state) {
    final columns = state.tableau.columns
        .map((column) => List<PlayingCard>.of(column))
        .toList();
    if (columnIndex < 0 || columnIndex >= columns.length) {
      return state;
    }
    if (startIndex < 0 || startIndex > columns[columnIndex].length) {
      return state;
    }

    columns[columnIndex].insertAll(startIndex, removedCards);
    if (flippedExposedCardOnApply && startIndex - 1 >= 0) {
      columns[columnIndex][startIndex - 1] =
          columns[columnIndex][startIndex - 1].copyWith(faceUp: false);
    }

    final nextCompleted = state.foundations.completedRuns > 0
        ? state.foundations.completedRuns - 1
        : 0;
    return state.copyWith(
      tableau: TableauPiles(columns),
      foundations: state.foundations.copyWith(completedRuns: nextCompleted),
    );
  }

  bool _sameCardIds(List<PlayingCard> a, List<PlayingCard> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) {
        return false;
      }
    }
    return true;
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
