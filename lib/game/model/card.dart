enum CardRank {
  ace(1, 'A'),
  two(2, '2'),
  three(3, '3'),
  four(4, '4'),
  five(5, '5'),
  six(6, '6'),
  seven(7, '7'),
  eight(8, '8'),
  nine(9, '9'),
  ten(10, '10'),
  jack(11, 'J'),
  queen(12, 'Q'),
  king(13, 'K');

  const CardRank(this.value, this.label);
  final int value;
  final String label;
}

enum CardSuit {
  spades('♠'),
  hearts('♥'),
  diamonds('♦'),
  clubs('♣');

  const CardSuit(this.symbol);
  final String symbol;
}

class PlayingCard {
  const PlayingCard({
    required this.id,
    required this.rank,
    required this.suit,
    required this.faceUp,
  });

  final int id;
  final CardRank rank;
  final CardSuit suit;
  final bool faceUp;

  PlayingCard copyWith({
    int? id,
    CardRank? rank,
    CardSuit? suit,
    bool? faceUp,
  }) {
    return PlayingCard(
      id: id ?? this.id,
      rank: rank ?? this.rank,
      suit: suit ?? this.suit,
      faceUp: faceUp ?? this.faceUp,
    );
  }
}
