import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:haylau_spider_solitaire/features/play/widgets/tableau_column_view.dart';
import 'package:haylau_spider_solitaire/game/model/card.dart';

void main() {
  testWidgets('hint highlights only specified startIndex+length segment', (
    tester,
  ) async {
    final cards = <PlayingCard>[
      const PlayingCard(
        id: 11,
        rank: CardRank.king,
        suit: CardSuit.spades,
        faceUp: true,
      ),
      const PlayingCard(
        id: 12,
        rank: CardRank.queen,
        suit: CardSuit.spades,
        faceUp: true,
      ),
      const PlayingCard(
        id: 13,
        rank: CardRank.jack,
        suit: CardSuit.spades,
        faceUp: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 100,
            height: 500,
            child: TableauColumnView(
              columnIndex: 0,
              cards: cards,
              tapEnabled: true,
              hintFlashOn: true,
              hintRuns: const <HintFlashRun>[
                HintFlashRun(startIndex: 1, length: 1),
              ],
              canDragFromIndex: (index) => index >= 0,
              onBuildDragPayload: (index) => DragRunPayload(
                fromColumn: 0,
                startIndex: index,
                cards: cards.sublist(index),
              ),
              canAcceptDrop: (_) => false,
              onAcceptDrop: (_) {},
              onIllegalDrop: () {},
              onCardTap: (_) {},
              onColumnTap: () {},
              onDragStarted: (_) {},
              onDragCanceled: () {},
              onDragCompleted: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('hinted-0-1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('hinted-0-0')), findsNothing);
    expect(find.byKey(const ValueKey<String>('hinted-0-2')), findsNothing);
  });
  testWidgets('source column hides dragged run tail without mutating cards', (
    tester,
  ) async {
    final cards = <PlayingCard>[
      const PlayingCard(
        id: 1,
        rank: CardRank.king,
        suit: CardSuit.spades,
        faceUp: true,
      ),
      const PlayingCard(
        id: 2,
        rank: CardRank.queen,
        suit: CardSuit.spades,
        faceUp: true,
      ),
      const PlayingCard(
        id: 3,
        rank: CardRank.jack,
        suit: CardSuit.spades,
        faceUp: true,
      ),
    ];

    final dragPayload = DragRunPayload(
      fromColumn: 0,
      startIndex: 1,
      cards: cards.sublist(1),
    );

    Widget buildUnderTest(DragRunPayload? activeDrag) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 100,
            height: 500,
            child: TableauColumnView(
              columnIndex: 0,
              cards: cards,
              tapEnabled: true,
              previewNextCardOnDrag: true,
              activeDragPayload: activeDrag,
              canDragFromIndex: (index) => index >= 1,
              onBuildDragPayload: (index) => DragRunPayload(
                fromColumn: 0,
                startIndex: index,
                cards: cards.sublist(index),
              ),
              canAcceptDrop: (_) => false,
              onAcceptDrop: (_) {},
              onIllegalDrop: () {},
              onCardTap: (_) {},
              onColumnTap: () {},
              onDragStarted: (_) {},
              onDragCanceled: () {},
              onDragCompleted: () {},
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildUnderTest(null));
    expect(
      find.byKey(const ValueKey<String>('column-0-card-2')),
      findsOneWidget,
    );
    expect(cards.length, 3);

    await tester.pumpWidget(buildUnderTest(dragPayload));
    expect(
      find.byKey(const ValueKey<String>('column-0-card-1')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('column-0-card-2')), findsNothing);
    expect(cards.length, 3);
  });
}
