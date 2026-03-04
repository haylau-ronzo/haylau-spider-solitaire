import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../game/model/card.dart';
import 'placeholder_card_view.dart';

class DragRunPayload {
  const DragRunPayload({
    required this.fromColumn,
    required this.startIndex,
    required this.cards,
  });

  final int fromColumn;
  final int startIndex;
  final List<PlayingCard> cards;
}

class HintFlashRun {
  const HintFlashRun({required this.startIndex, required this.length});

  final int startIndex;
  final int length;
}

class TableauColumnView extends StatelessWidget {
  const TableauColumnView({
    super.key,
    required this.columnIndex,
    required this.cards,
    required this.tapEnabled,
    required this.canDragFromIndex,
    required this.onBuildDragPayload,
    required this.canAcceptDrop,
    required this.onAcceptDrop,
    required this.onIllegalDrop,
    required this.onCardTap,
    required this.onColumnTap,
    required this.onDragStarted,
    required this.onDragCanceled,
    required this.onDragCompleted,
    this.previewNextCardOnDrag = false,
    this.activeDragPayload,
    this.selectedStartIndex,
    this.selectedLength,
    this.isValidTapTarget = false,
    this.hintRuns = const <HintFlashRun>[],
    this.hintFlashOn = false,
  });

  final int columnIndex;
  final List<PlayingCard> cards;
  final bool tapEnabled;
  final bool Function(int cardIndex) canDragFromIndex;
  final DragRunPayload Function(int cardIndex) onBuildDragPayload;
  final bool Function(DragRunPayload payload) canAcceptDrop;
  final void Function(DragRunPayload payload) onAcceptDrop;
  final VoidCallback onIllegalDrop;
  final void Function(int index) onCardTap;
  final VoidCallback onColumnTap;
  final ValueChanged<DragRunPayload> onDragStarted;
  final VoidCallback onDragCanceled;
  final VoidCallback onDragCompleted;
  final bool previewNextCardOnDrag;
  final DragRunPayload? activeDragPayload;
  final int? selectedStartIndex;
  final int? selectedLength;
  final bool isValidTapTarget;
  final List<HintFlashRun> hintRuns;
  final bool hintFlashOn;

  static const double _cardWidth = 72;
  static const double _cardHeight = 96;
  static const double _preferredFaceDownGap = 10;
  static const double _preferredFaceUpGap = 20;
  static const double _minimumFaceDownGap = 3;
  static const double _minimumFaceUpGap = 11;

  @override
  Widget build(BuildContext context) {
    final sourceDrag =
        activeDragPayload != null &&
            activeDragPayload!.fromColumn == columnIndex
        ? activeDragPayload!
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _computeLayout(cards, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tapEnabled ? onColumnTap : null,
          child: DragTarget<DragRunPayload>(
            onWillAcceptWithDetails: (details) => canAcceptDrop(details.data),
            onAcceptWithDetails: (details) => onAcceptDrop(details.data),
            builder: (context, candidateData, rejectedData) {
              final isCandidate = candidateData.isNotEmpty;
              final highlightColor = isCandidate || isValidTapTarget
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent;
              return Container(
                width: _cardWidth,
                height: layout.stackHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: highlightColor, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    for (var i = 0; i < cards.length; i++)
                      if (!_isHiddenBySourceDrag(sourceDrag, i))
                        Positioned(
                          key: ValueKey<String>('column-$columnIndex-card-$i'),
                          left: 5,
                          top: layout.offsets[i],
                          child: _buildCardOrRun(
                            context,
                            i,
                            layout.offsets,
                            sourceDrag: sourceDrag,
                          ),
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
              );
            },
          ),
        );
      },
    );
  }

  bool _isHiddenBySourceDrag(DragRunPayload? sourceDrag, int index) {
    if (sourceDrag == null) {
      return false;
    }
    return index > sourceDrag.startIndex &&
        index < sourceDrag.startIndex + sourceDrag.cards.length;
  }

  Widget _buildCardOrRun(
    BuildContext context,
    int index,
    List<double> offsets, {
    DragRunPayload? sourceDrag,
  }) {
    final card = cards[index];
    final isSelected =
        selectedStartIndex != null &&
        selectedLength != null &&
        index >= selectedStartIndex! &&
        index < selectedStartIndex! + selectedLength!;
    final isHinted =
        hintFlashOn &&
        hintRuns.any(
          (range) =>
              index >= range.startIndex &&
              index < range.startIndex + range.length,
        );
    final canDragRunStart = card.faceUp && canDragFromIndex(index);

    if (!canDragRunStart) {
      return GestureDetector(
        onTap: tapEnabled ? () => onCardTap(index) : null,
        child: isHinted
            ? KeyedSubtree(
                key: ValueKey<String>('hinted-$columnIndex-$index'),
                child: _decorateSelected(
                  context,
                  isSelected: isSelected,
                  isHinted: isHinted,
                  child: PlaceholderCardView(card: card),
                ),
              )
            : _decorateSelected(
                context,
                isSelected: isSelected,
                isHinted: isHinted,
                child: PlaceholderCardView(card: card),
              ),
      );
    }

    final payload = sourceDrag != null && sourceDrag.startIndex == index
        ? sourceDrag
        : onBuildDragPayload(index);
    if (payload.cards.isEmpty) {
      return GestureDetector(
        onTap: tapEnabled ? () => onCardTap(index) : null,
        child: isHinted
            ? KeyedSubtree(
                key: ValueKey<String>('hinted-$columnIndex-$index'),
                child: _decorateSelected(
                  context,
                  isSelected: isSelected,
                  isHinted: isHinted,
                  child: PlaceholderCardView(card: card),
                ),
              )
            : _decorateSelected(
                context,
                isSelected: isSelected,
                isHinted: isHinted,
                child: PlaceholderCardView(card: card),
              ),
      );
    }

    final runLength = math.min(payload.cards.length, offsets.length - index);
    final runCards = payload.cards.take(runLength).toList(growable: false);
    final runOffsets = List<double>.generate(
      runCards.length,
      (i) => offsets[index + i] - offsets[index],
    );

    final runWidgetBase = _decorateSelected(
      context,
      isSelected: isSelected,
      isHinted: isHinted,
      child: _RunStack(cards: runCards, offsets: runOffsets),
    );
    final runWidget = isHinted
        ? KeyedSubtree(
            key: ValueKey<String>('hinted-$columnIndex-$index'),
            child: runWidgetBase,
          )
        : runWidgetBase;

    final sourceWhileDragging = previewNextCardOnDrag
        ? _buildNextCardPreview(payload.startIndex)
        : Opacity(opacity: 0.25, child: runWidget);

    return LongPressDraggable<DragRunPayload>(
      data: payload,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: _DragGhost(cards: runCards),
      ),
      onDragStarted: () => onDragStarted(payload),
      onDragCompleted: onDragCompleted,
      onDraggableCanceled: (_, offset) {
        onIllegalDrop();
        onDragCanceled();
      },
      childWhenDragging: sourceWhileDragging,
      child: GestureDetector(
        onTap: tapEnabled ? () => onCardTap(index) : null,
        child: runWidget,
      ),
    );
  }

  Widget _decorateSelected(
    BuildContext context, {
    required bool isSelected,
    required bool isHinted,
    required Widget child,
  }) {
    final selectedColor = Theme.of(context).colorScheme.secondary;
    final hintColor = Theme.of(context).colorScheme.tertiary;
    final borderColor = isSelected
        ? selectedColor
        : (isHinted ? hintColor : null);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: borderColor != null
          ? BoxDecoration(
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: child,
    );
  }

  Widget _buildNextCardPreview(int dragStartIndex) {
    final nextIndex = dragStartIndex - 1;
    final child = nextIndex >= 0
        ? Transform.translate(
            offset: const Offset(0, -1),
            child: PlaceholderCardView(
              card: cards[nextIndex].faceUp
                  ? cards[nextIndex]
                  : cards[nextIndex].copyWith(faceUp: true),
            ),
          )
        : const _EmptyPreviewSlot();
    return Opacity(opacity: 0.35, child: child);
  }

  _TableauLayout _computeLayout(List<PlayingCard> cards, double maxHeight) {
    if (cards.isEmpty) {
      return const _TableauLayout(offsets: <double>[], stackHeight: 120);
    }

    final gapCount = math.max(0, cards.length - 1);
    final faceDownGapCount = List<bool>.generate(
      gapCount,
      (i) => !cards[i].faceUp,
    ).where((isFaceDown) => isFaceDown).length;
    final faceUpGapCount = gapCount - faceDownGapCount;

    var faceDownGap = _preferredFaceDownGap;
    var faceUpGap = _preferredFaceUpGap;

    if (maxHeight.isFinite && gapCount > 0) {
      final availableGapSpace = math.max(0.0, maxHeight - _cardHeight);
      var usedGapSpace =
          (faceDownGapCount * faceDownGap) + (faceUpGapCount * faceUpGap);

      if (usedGapSpace > availableGapSpace && faceDownGapCount > 0) {
        final reducibleFaceDown =
            (_preferredFaceDownGap - _minimumFaceDownGap) * faceDownGapCount;
        final neededReduction = usedGapSpace - availableGapSpace;
        final appliedReduction = math.min(reducibleFaceDown, neededReduction);
        faceDownGap =
            _preferredFaceDownGap - (appliedReduction / faceDownGapCount);
        usedGapSpace -= appliedReduction;
      }

      if (usedGapSpace > availableGapSpace && faceUpGapCount > 0) {
        final reducibleFaceUp =
            (_preferredFaceUpGap - _minimumFaceUpGap) * faceUpGapCount;
        final neededReduction = usedGapSpace - availableGapSpace;
        final appliedReduction = math.min(reducibleFaceUp, neededReduction);
        faceUpGap = _preferredFaceUpGap - (appliedReduction / faceUpGapCount);
      }
    }

    final offsets = <double>[];
    var currentTop = 0.0;
    for (var i = 0; i < cards.length; i++) {
      offsets.add(currentTop);
      if (i < cards.length - 1) {
        currentTop += cards[i].faceUp ? faceUpGap : faceDownGap;
      }
    }

    return _TableauLayout(
      offsets: offsets,
      stackHeight: currentTop + _cardHeight,
    );
  }
}

class _TableauLayout {
  const _TableauLayout({required this.offsets, required this.stackHeight});

  final List<double> offsets;
  final double stackHeight;
}

class _RunStack extends StatelessWidget {
  const _RunStack({required this.cards, required this.offsets});

  final List<PlayingCard> cards;
  final List<double> offsets;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: offsets.last + 84,
      child: Stack(
        children: [
          for (var i = 0; i < cards.length; i++)
            Positioned(
              left: 0,
              top: offsets[i],
              child: PlaceholderCardView(card: cards[i]),
            ),
        ],
      ),
    );
  }
}

class _EmptyPreviewSlot extends StatelessWidget {
  const _EmptyPreviewSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black38),
      ),
    );
  }
}

class _DragGhost extends StatelessWidget {
  const _DragGhost({required this.cards});

  final List<PlayingCard> cards;

  @override
  Widget build(BuildContext context) {
    const cardHeight = 96.0;
    const faceDownGap = 10.0;
    const faceUpGap = 20.0;

    final offsets = <double>[];
    var top = 0.0;
    for (var i = 0; i < cards.length; i++) {
      offsets.add(top);
      if (i < cards.length - 1) {
        top += cards[i].faceUp ? faceUpGap : faceDownGap;
      }
    }

    return SizedBox(
      width: 72,
      height: top + cardHeight,
      child: Stack(
        children: [
          for (var i = 0; i < cards.length; i++)
            Positioned(
              left: 5,
              top: offsets[i],
              child: Opacity(
                opacity: 0.92,
                child: PlaceholderCardView(card: cards[i]),
              ),
            ),
        ],
      ),
    );
  }
}
