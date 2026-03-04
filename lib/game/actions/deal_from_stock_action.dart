import '../model/card.dart';
import '../model/game_state.dart';
import '../model/piles.dart';
import 'game_action.dart';

class DealFromStockAction implements GameAction {
  const DealFromStockAction();

  @override
  String get type => 'dealFromStock';

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'type': type, 'payload': <String, dynamic>{}};
  }

  static DealFromStockAction fromJson(Map<String, dynamic> json) {
    final actionType = json['type'] as String?;
    if (actionType != 'dealFromStock') {
      throw FormatException('Invalid action type for DealFromStockAction.');
    }
    return const DealFromStockAction();
  }

  @override
  GameState apply(GameState state) {
    if (state.stock.cards.length < 10) {
      return state;
    }

    final newColumns = state.tableau.columns
        .map((c) => List<PlayingCard>.of(c))
        .toList();
    final newStock = List<PlayingCard>.of(state.stock.cards);
    final dealt = newStock.sublist(newStock.length - 10);
    newStock.removeRange(newStock.length - 10, newStock.length);

    for (var i = 0; i < 10; i++) {
      newColumns[i].add(dealt[i].copyWith(faceUp: true));
    }

    return state.copyWith(
      tableau: TableauPiles(newColumns),
      stock: StockPile(newStock),
      moves: state.moves + 1,
    );
  }

  @override
  GameState revert(GameState state) {
    final newColumns = state.tableau.columns
        .map((c) => List<PlayingCard>.of(c))
        .toList();
    final returned = <PlayingCard>[];

    for (var i = 9; i >= 0; i--) {
      if (newColumns[i].isEmpty) {
        return state;
      }
      returned.insert(0, newColumns[i].removeLast().copyWith(faceUp: false));
    }

    final newStock = List<PlayingCard>.of(state.stock.cards)..addAll(returned);
    return state.copyWith(
      tableau: TableauPiles(newColumns),
      stock: StockPile(newStock),
      moves: state.moves > 0 ? state.moves - 1 : 0,
    );
  }
}
