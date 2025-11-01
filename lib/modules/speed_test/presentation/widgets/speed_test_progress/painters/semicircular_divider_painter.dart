import 'dart:math' as math;
import 'package:flutter/material.dart';

class SemicircularDividerPainter extends CustomPainter {
  final double strokeWidth;

  SemicircularDividerPainter({this.strokeWidth = 2.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;

    const startAngle = math.pi * 0.85;
    const sweepAngle = math.pi * 1.3;

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
