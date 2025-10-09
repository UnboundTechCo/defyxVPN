import 'package:flutter/material.dart';

class AnimatedGridPainter extends CustomPainter {
  final Animation<double> animation;
  final Color gridColor;
  final double strokeWidth;

  AnimatedGridPainter({
    required this.animation,
    this.gridColor = Colors.grey,
    this.strokeWidth = 1.0,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // final offset = 1.0 - (animation.value % 1.0); // From bottom to top
    final offset = animation.value % 1.0; // From top to bottom

    final horizontalSpacing = size.height / 8;
    final centerX = size.width / 2;

    final bottomWidth = size.width;
    final topWidth = size.width * 0.15;

    for (int i = -2; i < 11; i++) {
      final y = i * horizontalSpacing + (offset * horizontalSpacing);

      if (y >= 0 && y <= size.height) {
        final perspectiveRatio = 1.0 - (y / size.height);

        final lineWidth =
            topWidth + (bottomWidth - topWidth) * (1.0 - perspectiveRatio);
        final lineStartX = centerX - lineWidth / 2;
        final lineEndX = centerX + lineWidth / 2;

        final alpha = 0.05 + (1.0 - perspectiveRatio) * 0.25;

        final fadePaint = Paint()
          ..color = gridColor.withValues(alpha: alpha)
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

        canvas.drawLine(
          Offset(lineStartX, y),
          Offset(lineEndX, y),
          fadePaint,
        );
      }
    }

    final numVerticalLines = 10;

    for (int i = 0; i <= numVerticalLines; i++) {
      final bottomRatio = i / numVerticalLines;

      final bottomX = bottomRatio * size.width;

      final topX = centerX - topWidth / 2 + (bottomRatio * topWidth);

      final distanceFromCenter = (bottomRatio - 0.5).abs() / 0.5;
      final alpha = 0.05 + (1.0 - distanceFromCenter) * 0.2;

      final fadePaint = Paint()
        ..color = gridColor.withValues(alpha: alpha)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(bottomX, size.height),
        Offset(topX, 0),
        fadePaint,
      );
    }
  }

  @override
  bool shouldRepaint(AnimatedGridPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
