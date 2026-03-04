import '../../../game/model/card.dart';

String suitToSymbol(CardSuit suit) {
  switch (suit) {
    case CardSuit.spades:
      return '\u2660';
    case CardSuit.hearts:
      return '\u2665';
    case CardSuit.diamonds:
      return '\u2666';
    case CardSuit.clubs:
      return '\u2663';
  }
}

bool isRedSuit(CardSuit suit) {
  switch (suit) {
    case CardSuit.hearts:
    case CardSuit.diamonds:
      return true;
    case CardSuit.spades:
    case CardSuit.clubs:
      return false;
  }
}

String buildCornerLabel(CardRank rank, CardSuit suit) {
  return '${rank.label}${suitToSymbol(suit)}';
}
