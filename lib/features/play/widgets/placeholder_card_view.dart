import 'package:flutter/material.dart';

import '../../../game/model/card.dart';
import 'card_face_label.dart';

class PlaceholderCardView extends StatelessWidget {
  const PlaceholderCardView({super.key, required this.card});

  final PlayingCard card;

  @override
  Widget build(BuildContext context) {
    final label = buildCornerLabel(card.rank, card.suit);
    final textColor = isRedSuit(card.suit)
        ? Colors.red.shade800
        : Colors.black87;
    final fontSize = card.rank == CardRank.ten ? 12.0 : 13.0;

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
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: textColor,
            fontSize: fontSize,
            height: 1,
          ),
        ),
      ),
    );
  }
}
