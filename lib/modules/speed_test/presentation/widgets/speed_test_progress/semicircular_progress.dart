import 'dart:math' as math;
import 'package:flutter/material.dart';

class SemicircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  SemicircularProgressPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 12.0,
  });

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
