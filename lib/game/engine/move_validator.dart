import '../model/card.dart';

class MoveValidator {
  const MoveValidator();

  bool canMoveStack({
    required List<PlayingCard> fromColumnCards,
    required int startIndex,
    required List<PlayingCard> toColumnCards,
  }) {
    if (startIndex < 0 || startIndex >= fromColumnCards.length) {
      return false;
    }

    final moving = fromColumnCards.sublist(startIndex);
    if (moving.any((card) => !card.faceUp)) {
      return false;
    }

    for (var i = 0; i < moving.length - 1; i++) {
      if (moving[i].rank.value != moving[i + 1].rank.value + 1) {
        return false;
      }
    }

    if (toColumnCards.isEmpty) {
      return true;
    }

    final target = toColumnCards.last;
    final firstMoving = moving.first;
    return target.faceUp && target.rank.value == firstMoving.rank.value + 1;
  }
}
