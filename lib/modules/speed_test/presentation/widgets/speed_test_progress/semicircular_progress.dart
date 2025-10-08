import 'dart:math' as math;
import 'package:flutter/material.dart';

class SemicircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final Animation<double>? animation;

  SemicircularProgressPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 12.0,
    this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - strokeWidth / 2;

    const startAngle = math.pi * 0.85;
    const sweepAngle = math.pi * 1.3;

    final backgroundPaint = Paint()
      ..color = Colors.grey.shade300.withValues(alpha: 0.3)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    if (progress > 0) {
      final layers = 5;
      final layerSpacing = 1.5;
      final totalOffset = (layers - 1) * layerSpacing;
      final middleLayerOffset = totalOffset / 2;

      for (int i = 0; i < layers; i++) {
        final layerRadius = radius + middleLayerOffset - (i * layerSpacing);
        final gradient = _createGradient(color, center, layerRadius);

        final progressPaint = Paint()
          ..shader = gradient
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: layerRadius),
          startAngle,
          sweepAngle * progress,
          false,
          progressPaint,
        );
      }

      _drawProgressIndicator(
        canvas,
        center,
        radius,
        progress,
        color,
      );
    }
  }

  Shader _createGradient(Color baseColor, Offset center, double radius) {
    // Create gradient colors based on the color (Green for download, Blue for upload)
    List<Color> gradientColors;

    if (baseColor == Colors.green) {
      // Green gradient for download (lighter green to vibrant green)
      gradientColors = [
        const Color(0xFF66FF66), // Light green start
        const Color(0xFF00FF00), // Vibrant green
        const Color(0xFF00DD00), // Medium green
      ];
    } else if (baseColor == Colors.blue) {
      // Blue gradient for upload (lighter blue to vibrant blue)
      gradientColors = [
        const Color(0xFF66B3FF), // Light blue start
        const Color(0xFF0099FF), // Vibrant blue
        const Color(0xFF0077DD), // Medium blue
      ];
    } else if (baseColor == Colors.orange) {
      // Orange gradient for error/unstable state
      gradientColors = [
        const Color(0xFFFFAA66), // Light orange
        const Color(0xFFFF8833), // Orange
        const Color(0xFFFF6600), // Dark orange
      ];
    } else {
      // Default gradient (use the base color)
      gradientColors = [
        baseColor.withValues(alpha: 0.7),
        baseColor,
        baseColor.withValues(alpha: 0.9),
      ];
    }

    const startAngle = math.pi * 0.85;
    const sweepAngle = math.pi * 1.3;

    return SweepGradient(
      colors: gradientColors,
      startAngle: startAngle,
      endAngle: startAngle + (sweepAngle * progress),
    ).createShader(Rect.fromCircle(center: center, radius: radius));
  }

  void _drawProgressIndicator(Canvas canvas, Offset center, double radius,
      double progress, Color color) {
    // Calculate position of the indicator dot at the end of the arc
    const startAngle = math.pi * 0.85;
    const sweepAngle = math.pi * 1.3;
    final angle = startAngle + (sweepAngle * progress);
    final dotX = center.dx + radius * math.cos(angle);
    final dotY = center.dy + radius * math.sin(angle);
    final dotPosition = Offset(dotX, dotY);

    // Draw outer glow (subtle)
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(dotPosition, 6.0, glowPaint);

    // Draw white dot indicator
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(dotPosition, 5.0, dotPaint);

    // Draw inner highlight for 3D effect
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(dotPosition.dx - 1, dotPosition.dy - 1),
      2.0,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(SemicircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class SemicircularDividerPainter extends CustomPainter {
  final double strokeWidth;

  SemicircularDividerPainter({this.strokeWidth = 2.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;

    // Arc parameters: 65% of circle (same as progress painter) centered on y-axis (1.5π)
    const startAngle = math.pi * 0.85; // Start at ~153°
    const sweepAngle = math.pi * 1.3; // Sweep 234° (65% of circle)

    final paint = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

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
    // Animation offset (0.0 to 1.0, repeating) - reversed for bottom to top
    final offset = 1.0 - (animation.value % 1.0);

    // Grid configuration
    final horizontalSpacing = size.height / 8; // 8 horizontal lines
    final centerX = size.width / 2;

    // Perspective settings - top narrows to near 0
    final bottomWidth = size.width; // Full width at bottom
    final topWidth = size.width * 0.15; // 15% width at top (near 0)

    // Draw horizontal lines with animation and perspective (moving from bottom to top)
    for (int i = -2; i < 11; i++) {
      final y = i * horizontalSpacing + (offset * horizontalSpacing);

      if (y >= 0 && y <= size.height) {
        // Calculate perspective ratio (0 at top, 1 at bottom)
        final perspectiveRatio = 1.0 - (y / size.height);

        // Calculate line width based on perspective
        final lineWidth =
            topWidth + (bottomWidth - topWidth) * (1.0 - perspectiveRatio);
        final lineStartX = centerX - lineWidth / 2;
        final lineEndX = centerX + lineWidth / 2;

        // Create a fading effect - fade out at the top, brighter at bottom
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

    // Draw converging vertical grid lines (multiple lines with perspective)
    final numVerticalLines = 10; // Number of vertical grid lines

    for (int i = 0; i <= numVerticalLines; i++) {
      // Position along the bottom edge (0.0 to 1.0)
      final bottomRatio = i / numVerticalLines;

      // Calculate start point at bottom (full width)
      final bottomX = bottomRatio * size.width;

      // Calculate end point at top (narrow width) with same ratio
      final topX = centerX - topWidth / 2 + (bottomRatio * topWidth);

      // Fade based on distance from center
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
