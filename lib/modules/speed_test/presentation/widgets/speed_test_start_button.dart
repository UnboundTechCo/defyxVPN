import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;
import '../../models/speed_test_result.dart';

class SpeedTestStartButton extends StatefulWidget {
  final SpeedTestStep currentStep;
  final SpeedTestStep? previousStep;
  final bool isEnabled;
  final VoidCallback onTap;

  const SpeedTestStartButton({
    super.key,
    required this.currentStep,
    required this.isEnabled,
    required this.onTap,
    this.previousStep,
  });

  @override
  State<SpeedTestStartButton> createState() => _SpeedTestStartButtonState();
}

class _SpeedTestStartButtonState extends State<SpeedTestStartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.currentStep == SpeedTestStep.ready) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SpeedTestStartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentStep == SpeedTestStep.ready && oldWidget.currentStep != SpeedTestStep.ready) {
      _animationController.repeat(reverse: true);
    } else if (widget.currentStep != SpeedTestStep.ready &&
        oldWidget.currentStep == SpeedTestStep.ready) {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  IconData _getIcon() {
    if (widget.currentStep == SpeedTestStep.ready && widget.previousStep == null) {
      return Icons.near_me_outlined;
    } else {
      return Icons.cached_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isEnabled ? widget.onTap : null,
      child: Container(
        width: 60.w,
        height: 60.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.currentStep == SpeedTestStep.ready && widget.previousStep == null)
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(50.w, 50.w),
                    painter: RadialLinesPainter(
                      progress: _animation.value,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            Positioned(
              right: 15.h,
              bottom: widget.currentStep == SpeedTestStep.ready && widget.previousStep == null
                  ? 15.h
                  : 0,
              child: Transform.rotate(
                angle: widget.currentStep == SpeedTestStep.ready && widget.previousStep == null
                    ? 15 / 3.14
                    : 0,
                child: Icon(
                  _getIcon(),
                  color: Colors.white,
                  size: widget.currentStep == SpeedTestStep.ready && widget.previousStep == null
                      ? 20.sp
                      : 36.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RadialLinesPainter extends CustomPainter {
  final double progress;
  final Color color;

  RadialLinesPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.3 + (progress * 0.4))
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final List<double> lineAngles = [
      math.pi * 0.875,
      math.pi,
      math.pi * 1.125,
      math.pi * 1.25,
      math.pi * 1.375,
      math.pi * 1.5,
      math.pi * 1.625,
    ];

    for (final angle in lineAngles) {
      final startRadius = radius * 0.6 + (progress * radius * 0.15);
      final endRadius = radius * 0.75 + (progress * radius * 0.2);

      final startX = center.dx + startRadius * math.cos(angle);
      final startY = center.dy + startRadius * math.sin(angle);
      final endX = center.dx + endRadius * math.cos(angle);
      final endY = center.dy + endRadius * math.sin(angle);

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(RadialLinesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
