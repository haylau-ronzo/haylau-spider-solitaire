import '../model/card.dart';
import '../model/game_state.dart';
import '../model/piles.dart';
import 'game_action.dart';

class MoveStackAction implements GameAction {
  const MoveStackAction({
    required this.fromColumn,
    required this.toColumn,
    required this.startIndex,
    required this.movedCards,
    required this.flippedSourceCardOnApply,
  });

  final int fromColumn;
  final int toColumn;
  final int startIndex;
  final List<PlayingCard> movedCards;
  final bool flippedSourceCardOnApply;

  @override
  String get type => 'moveStack';

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'payload': <String, dynamic>{
        'fromColumn': fromColumn,
        'toColumn': toColumn,
        'startIndex': startIndex,
        'movedCards': movedCards.map(_encodeCard).toList(),
        'flippedSourceCardOnApply': flippedSourceCardOnApply,
      },
    };
  }

  static MoveStackAction fromJson(Map<String, dynamic> json) {
    final actionType = json['type'] as String?;
    if (actionType != 'moveStack') {
      throw FormatException('Invalid action type for MoveStackAction.');
    }

    final payload = json['payload'] as Map<String, dynamic>?;
    if (payload == null) {
      throw FormatException('Missing moveStack payload.');
    }

    return MoveStackAction(
      fromColumn: payload['fromColumn'] as int,
      toColumn: payload['toColumn'] as int,
      startIndex: payload['startIndex'] as int,
      movedCards: (payload['movedCards'] as List<dynamic>)
          .map((card) => _decodeCard(card as Map<String, dynamic>))
          .toList(),
      flippedSourceCardOnApply: payload['flippedSourceCardOnApply'] as bool,
    );
  }

  @override
  GameState apply(GameState state) {
    final columns = state.tableau.columns
        .map((column) => List<PlayingCard>.of(column))
        .toList();
    if (!_isValidColumns(columns)) {
      return state;
    }
    if (startIndex < 0 ||
        startIndex + movedCards.length > columns[fromColumn].length) {
      return state;
    }

    final slice = columns[fromColumn].sublist(
      startIndex,
      startIndex + movedCards.length,
    );
    if (!_sameCardIds(slice, movedCards)) {
      return state;
    }

    columns[fromColumn].removeRange(startIndex, startIndex + movedCards.length);
    columns[toColumn].addAll(movedCards);

    if (flippedSourceCardOnApply && columns[fromColumn].isNotEmpty) {
      final topIndex = columns[fromColumn].length - 1;
      columns[fromColumn][topIndex] = columns[fromColumn][topIndex].copyWith(
        faceUp: true,
      );
    }

    return state.copyWith(
      tableau: TableauPiles(columns),
      moves: state.moves + 1,
    );
  }

  @override
  GameState revert(GameState state) {
    final columns = state.tableau.columns
        .map((column) => List<PlayingCard>.of(column))
        .toList();
    if (!_isValidColumns(columns)) {
      return state;
    }
    if (columns[toColumn].length < movedCards.length) {
      return state;
    }

    final slice = columns[toColumn].sublist(
      columns[toColumn].length - movedCards.length,
    );
    if (!_sameCardIds(slice, movedCards)) {
      return state;
    }

    columns[toColumn].removeRange(
      columns[toColumn].length - movedCards.length,
      columns[toColumn].length,
    );
    columns[fromColumn].addAll(movedCards);

    if (flippedSourceCardOnApply &&
        startIndex - 1 >= 0 &&
        startIndex - 1 < columns[fromColumn].length) {
      columns[fromColumn][startIndex - 1] = columns[fromColumn][startIndex - 1]
          .copyWith(faceUp: false);
    }

    return state.copyWith(
      tableau: TableauPiles(columns),
      moves: state.moves > 0 ? state.moves - 1 : 0,
    );
  }

  bool _isValidColumns(List<List<PlayingCard>> columns) {
    return fromColumn >= 0 &&
        fromColumn < columns.length &&
        toColumn >= 0 &&
        toColumn < columns.length &&
        fromColumn != toColumn;
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
