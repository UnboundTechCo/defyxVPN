import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomToast extends StatelessWidget {
  final String message;
  final IconData? icon;
  final String? svgIcon;
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final double borderRadius;
  final EdgeInsets padding;
  final Duration duration;
  final VoidCallback? onDismiss;

  const CustomToast({
    Key? key,
    required this.message,
    this.icon,
    this.svgIcon,
    this.backgroundColor = Colors.black,
    this.textColor = Colors.white,
    this.iconColor = Colors.white,
    this.borderRadius = 8.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
    this.duration = const Duration(seconds: 3),
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius.r),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: textColor,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  static void show({
    required BuildContext context,
    required String message,
    IconData? icon,
    String? svgIcon,
    Color backgroundColor = Colors.black,
    Color textColor = Colors.white,
    Color iconColor = Colors.white,
    double borderRadius = 6.0,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onDismiss,
  }) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100.h,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: CustomToast(
            message: message,
            icon: icon,
            svgIcon: svgIcon,
            backgroundColor: backgroundColor,
            textColor: textColor,
            iconColor: iconColor,
            borderRadius: borderRadius,
            padding: padding,
            duration: duration,
            onDismiss: onDismiss,
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(duration, () {
      overlayEntry.remove();
      if (onDismiss != null) {
        onDismiss();
      }
    });
  }
}