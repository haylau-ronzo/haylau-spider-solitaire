import 'package:flutter/material.dart';

import '../../../game/model/card.dart';
import 'placeholder_card_view.dart';

class TableauColumnView extends StatelessWidget {
  const TableauColumnView({
    super.key,
    required this.cards,
    required this.onTap,
    this.isSelected = false,
  });

  final List<PlayingCard> cards;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SizedBox(
          width: 72,
          child: Stack(
            children: [
              for (var i = 0; i < cards.length; i++)
                Positioned(
                  left: 5,
                  top: i * 18,
                  child: PlaceholderCardView(card: cards[i]),
                ),
              if (cards.isEmpty)
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
