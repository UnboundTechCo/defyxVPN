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

    final topShadowHeight = size.height * 0.3;
    final topShadowTopWidth = topWidth;
    final topShadowBottomWidth =
        topWidth + (bottomWidth - topWidth) * (topShadowHeight / size.height);

    final topShadowPath = Path()
      ..moveTo(centerX - topShadowTopWidth / 2, 0)
      ..lineTo(centerX + topShadowTopWidth / 2, 0)
      ..lineTo(centerX + topShadowBottomWidth / 2, topShadowHeight)
      ..lineTo(centerX - topShadowBottomWidth / 2, topShadowHeight)
      ..close();

    final topShadowRect = Rect.fromLTWH(0, 0, size.width, topShadowHeight);
    final topGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.grey.withValues(alpha: 0.15),
        Colors.grey.withValues(alpha: 0.0),
      ],
    );

    final topShadowPaint = Paint()
      ..shader = topGradient.createShader(topShadowRect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(topShadowPath, topShadowPaint);

    for (int i = -2; i < 11; i++) {
      final y = i * horizontalSpacing + (offset * horizontalSpacing);

      if (y >= 0 && y <= size.height) {
        final perspectiveRatio = 1.0 - (y / size.height);

        final lineWidth = topWidth + (bottomWidth - topWidth) * (1.0 - perspectiveRatio);
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

    final bottomShadowHeight = size.height * 0.4;
    final bottomShadowStartY = size.height - bottomShadowHeight;
    final bottomShadowTopWidth =
        topWidth + (bottomWidth - topWidth) * (bottomShadowStartY / size.height);
    final bottomShadowBottomWidth = bottomWidth;

    final bottomShadowPath = Path()
      ..moveTo(centerX - bottomShadowTopWidth / 2, bottomShadowStartY)
      ..lineTo(centerX + bottomShadowTopWidth / 2, bottomShadowStartY)
      ..lineTo(centerX + bottomShadowBottomWidth / 2, size.height)
      ..lineTo(centerX - bottomShadowBottomWidth / 2, size.height)
      ..close();

    final bottomShadowRect = Rect.fromLTWH(0, bottomShadowStartY, size.width, bottomShadowHeight);
    final bottomGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.grey.withValues(alpha: 0.0),
        Colors.grey.withValues(alpha: 0.15),
      ],
    );

    final bottomShadowPaint = Paint()
      ..shader = bottomGradient.createShader(bottomShadowRect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(bottomShadowPath, bottomShadowPaint);
  }

  @override
  bool shouldRepaint(AnimatedGridPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
