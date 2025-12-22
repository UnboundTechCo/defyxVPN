import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:toastification/toastification.dart';

class SettingsToastMessage extends StatelessWidget {
  final String message;

  const SettingsToastMessage({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        message,
        textAlign: TextAlign.left,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  static void show(BuildContext context, String message) {
    toastification.show(
      context: context,
      description: Text(
        message,
        style: TextStyle(color: Colors.white, fontSize: 15.0),
      ),
      style: ToastificationStyle.fillColored,
      backgroundColor: Colors.black,
      primaryColor: Colors.black,
      showIcon: false,
      closeButton: ToastCloseButton(
        showType: CloseButtonShowType.none,
      ),
      alignment: Alignment.bottomCenter,
      borderRadius: BorderRadius.circular(6.0),
      padding: const EdgeInsets.all(16.0),
      autoCloseDuration: const Duration(seconds: 5),
      margin: const EdgeInsets.symmetric(vertical: 80.0, horizontal: 25.0),
    );
  }
}
