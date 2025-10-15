import 'dart:math' as math;
import 'package:defyx_vpn/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

enum ProgressStep { upload, download }

class SemicircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final Animation<double>? animation;
  final ProgressStep showStep;

  SemicircularProgressPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 12.0,
    this.animation,
    this.showStep = ProgressStep.upload,
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

    final animatedProgress = animation?.value ?? progress;

    if (animatedProgress > 0) {
      // Draw shadow first
      final shadowPaint = Paint()
        ..color = const Color(0x6687BD23) // #87BD2366
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 17);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * animatedProgress,
        false,
        shadowPaint,
      );

      final layers = 5;
      final layerSpacing = 1.5;
      final totalOffset = (layers - 1) * layerSpacing;
      final middleLayerOffset = totalOffset / 2;

      for (int i = 0; i < layers; i++) {
        final layerRadius = radius + middleLayerOffset - (i * layerSpacing);
        final gradient = _createGradient(color, center, layerRadius, animatedProgress);

        final progressPaint = Paint()
          ..shader = gradient
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: layerRadius),
          startAngle,
          sweepAngle * animatedProgress,
          false,
          progressPaint,
        );
      }

      _drawProgressIndicator(
        canvas,
        center,
        radius,
        animatedProgress,
        color,
      );
    }
  }

  Shader _createGradient(Color baseColor, Offset center, double radius, double progress) {
    List<Color> gradientColors;

    if (baseColor == Colors.green) {
      gradientColors = [
        AppColors.downloadColor,
        AppColors.downloadColor,
        AppColors.downloadColor,
        // const Color(0xFF00FF00),
        // const Color(0xFF00DD00),
      ];
    } else if (baseColor == Colors.blue) {
      gradientColors = [
        AppColors.uploadColor,
        AppColors.uploadColor,
        AppColors.uploadColor,
        // const Color(0xFF0099FF),
        // const Color(0xFF0077DD),
      ];
    } else if (baseColor == Colors.orange) {
      gradientColors = [
        AppColors.warningColor,
        AppColors.warningColor,
        AppColors.warningColor,
        // const Color(0xFFFF8833),
        // const Color(0xFFFF6600),
      ];
    } else {
      gradientColors = [
        baseColor,
        baseColor,
        baseColor,
        // baseColor.withValues(alpha: 0.7),
        // baseColor.withValues(alpha: 0.9),
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

  void _drawProgressIndicator(
      Canvas canvas, Offset center, double radius, double progress, Color color) {
    const startAngle = math.pi * 0.85;
    const sweepAngle = math.pi * 1.3;
    final angle = startAngle + (sweepAngle * progress);
    final dotX = center.dx + radius * math.cos(angle);
    final dotY = center.dy + radius * math.sin(angle);
    final dotPosition = Offset(dotX, dotY);

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(dotPosition, 4.0, glowPaint);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(dotPosition, 4.0, dotPaint);

    final highlightPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
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
