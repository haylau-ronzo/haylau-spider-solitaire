import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/features/play/widgets/card_face_label.dart';
import 'package:haylau_spider_solitaire/game/model/card.dart';

void main() {
  test('suit mapping returns Unicode symbols and no unknown marker', () {
    expect(suitToSymbol(CardSuit.spades), '\u2660');
    expect(suitToSymbol(CardSuit.hearts), '\u2665');
    expect(suitToSymbol(CardSuit.diamonds), '\u2666');
    expect(suitToSymbol(CardSuit.clubs), '\u2663');

    for (final suit in CardSuit.values) {
      expect(suitToSymbol(suit), isNot('?'));
    }

    expect(isRedSuit(CardSuit.hearts), isTrue);
    expect(isRedSuit(CardSuit.diamonds), isTrue);
    expect(isRedSuit(CardSuit.spades), isFalse);
    expect(isRedSuit(CardSuit.clubs), isFalse);
  });
}
