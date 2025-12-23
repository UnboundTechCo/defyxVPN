import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:toastification/toastification.dart';

class ToastUtil {
  static void showToast(String message) {
    toastification.show(
      description: Text(
        message,
        style: TextStyle(
          color: Colors.white,
          fontSize: 15.sp,
          fontFamily: 'Lato',
          fontWeight: FontWeight.w400,
        ),
      ),
      style: ToastificationStyle.fillColored,
      backgroundColor: Colors.black,
      primaryColor: Colors.black,
      showIcon: false,
      closeButton: ToastCloseButton(
        showType: CloseButtonShowType.none,
      ),
      alignment: Alignment(0, 0.7),
      borderRadius: BorderRadius.circular(6.0),
      padding: const EdgeInsets.all(16.0),
      autoCloseDuration: const Duration(seconds: 5),
      margin: const EdgeInsets.symmetric(horizontal: 25.0),
    );
  }
}
