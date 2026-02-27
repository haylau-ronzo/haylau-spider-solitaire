import 'card.dart';

class TableauPiles {
  TableauPiles(List<List<PlayingCard>> columns)
    : columns = List.unmodifiable(
        columns.map((column) => List<PlayingCard>.unmodifiable(column)),
      );

  final List<List<PlayingCard>> columns;

  TableauPiles copyWith({List<List<PlayingCard>>? columns}) {
    return TableauPiles(columns ?? this.columns);
  }
}

class StockPile {
  StockPile(List<PlayingCard> cards)
    : cards = List<PlayingCard>.unmodifiable(cards);

  final List<PlayingCard> cards;

  StockPile copyWith({List<PlayingCard>? cards}) {
    return StockPile(cards ?? this.cards);
  }
}

class Foundations {
  const Foundations({required this.completedRuns});

  final int completedRuns;

  Foundations copyWith({int? completedRuns}) {
    return Foundations(completedRuns: completedRuns ?? this.completedRuns);
  }
}
