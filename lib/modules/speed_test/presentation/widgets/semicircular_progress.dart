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

    // Arc parameters: 75% of circle (270 degrees)
    const startAngle = math.pi * 0.78; // Start at ~112.5°
    const sweepAngle = math.pi * 1.45; // Sweep 315° (87.5% of circle)

    // Draw background track (light gray/white)
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
      // Create gradient shader for progress arc
      final gradient = _createGradient(color, center, radius);

      final progressPaint = Paint()
        ..shader = gradient
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Draw progress arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        progressPaint,
      );

      // Draw indicator dot at the end of progress
      _drawProgressIndicator(canvas, center, radius, progress, color);
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

    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    return SweepGradient(
      colors: gradientColors,
      startAngle: startAngle,
      endAngle: startAngle + (sweepAngle * progress),
    ).createShader(Rect.fromCircle(center: center, radius: radius));
  }

  void _drawProgressIndicator(Canvas canvas, Offset center, double radius,
      double progress, Color color) {
    // Calculate position of the indicator dot at the end of the arc
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;
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

    // Arc parameters: 75% of circle (same as progress painter)
    const startAngle = math.pi * 0.75; // Start at ~112.5°
    const sweepAngle = math.pi * 1.5; // Sweep 315° (87.5% of circle)

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
