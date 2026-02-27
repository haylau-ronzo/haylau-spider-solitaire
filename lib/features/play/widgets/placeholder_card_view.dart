import 'package:flutter/material.dart';

import '../../../game/model/card.dart';

class PlaceholderCardView extends StatelessWidget {
  const PlaceholderCardView({super.key, required this.card});

  final PlayingCard card;

  @override
  Widget build(BuildContext context) {
    final isRed =
        card.suit == CardSuit.hearts || card.suit == CardSuit.diamonds;
    final textColor = isRed ? Colors.red.shade800 : Colors.black87;

    if (!card.faceUp) {
      return Container(
        width: 62,
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF2E5A9A),
          border: Border.all(color: Colors.white70),
        ),
      );
    }

    return Container(
      width: 62,
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        border: Border.all(color: Colors.black26),
      ),
      padding: const EdgeInsets.all(6),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          '${card.rank.label}${card.suit.symbol}',
          style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
        ),
      ),
    );
  }
}
