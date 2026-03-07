import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../game/model/card.dart';
import 'card_face_label.dart';

class PlaceholderCardView extends StatelessWidget {
  const PlaceholderCardView({super.key, required this.card});

  final PlayingCard card;
  static const double _width = 62;
  static const double _height = 84;
  static const double _radius = 8;

  @override
  Widget build(BuildContext context) {
    final label = buildCornerLabel(card.rank, card.suit);
    final textColor = isRedSuit(card.suit)
        ? const Color(0xFF8B1E2D)
        : const Color(0xFF1E1E1D);
    final fontSize = card.rank == CardRank.ten ? 12.0 : 13.0;

    if (!card.faceUp) {
      final isRedBack = isRedSuit(card.suit);
      final backBase = isRedBack ? const Color(0xFF9C2538) : const Color(0xFF214D9A);
      final backDark = isRedBack ? const Color(0xFF6F1A29) : const Color(0xFF17376E);
      final backLight = isRedBack ? const Color(0xFFC74A5C) : const Color(0xFF3C6FC3);

      return Container(
        width: _width,
        height: _height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: const Color(0xFFEDE3CB), width: 1.2),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [backDark, backBase, backLight],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius - 0.4),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CardBackPatternPainter(
                    lineColor: Colors.white.withValues(alpha: 0.18),
                    dotColor: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: _SpiderMedallion(accent: AppPalette.accentGold),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(_radius - 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFDF7), Color(0xFFF5F0E2)],
        ),
        border: Border.all(color: const Color(0xFFBDAE8E), width: 1),
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

class _CardBackPatternPainter extends CustomPainter {
  const _CardBackPatternPainter({required this.lineColor, required this.dotColor});

  final Color lineColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    const spacing = 8.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), linePaint);
    }
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x + 1.5, y + 1.5), 0.9, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CardBackPatternPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor || oldDelegate.dotColor != dotColor;
  }
}

class _SpiderMedallion extends StatelessWidget {
  const _SpiderMedallion({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ring = accent.withValues(alpha: 0.48);
    final fill = const Color(0xFFFFF8E7).withValues(alpha: 0.18);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 1.2),
        color: fill,
      ),
      child: Center(
        child: Text(
          '\u2660',
          style: TextStyle(
            fontSize: 13,
            color: accent.withValues(alpha: 0.72),
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
