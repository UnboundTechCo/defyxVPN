import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppDialog extends StatelessWidget {
  final Widget child;
  final double maxHeightFactor;
  final EdgeInsetsGeometry? padding;

  const AppDialog({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.9,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.r),
      ),
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: 0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: screenHeight * maxHeightFactor,
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            child: Padding(
              padding: padding ?? EdgeInsets.all(20.w),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}