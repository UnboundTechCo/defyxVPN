import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:defyx_vpn/shared/widgets/custom_toast.dart';
import 'package:defyx_vpn/app/app.dart';

class ToastUtil {
  static void showToast(String message) {
    // Get the current context from the navigator key
    final context = navigatorKey.currentContext;
    
    if (context != null) {
      // Use the custom toast if context is available
      CustomToast.show(
        context: context,
        message: message,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        borderRadius: 8.0,
      );
    } else {
      // Fallback to Fluttertoast if context is not available
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }
  
  // For use in specific screens where you want to show the custom toast
  static void showCustomToast({
    required BuildContext context,
    required String message,
    IconData? icon,
    String? svgIcon,
  }) {
    CustomToast.show(
      context: context,
      message: message,
      icon: icon,
      svgIcon: svgIcon,
      backgroundColor: const Color(0xFF1A1A1A),
      textColor: Colors.white,
      iconColor: Colors.white,
      borderRadius: 8.0,
    );
  }
}