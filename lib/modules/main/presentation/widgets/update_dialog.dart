import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/shared/global_vars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateType {
  optional,
  required,
}

class CustomUpdateDialog {
  static Future<bool?> showUpdateDialog(
    BuildContext context, {
    required UpdateType updateType,
    List<dynamic>? features,
    String? description,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: updateType == UpdateType.optional,
      builder: (BuildContext context) {
        return PopScope(
          canPop: updateType == UpdateType.optional,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
            child: Container(
              width: MediaQuery.of(context).size.width - 32.w,
              padding: EdgeInsets.only(left: 31.w, right: 31.w, top: 24.h, bottom: 24.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    updateType == UpdateType.optional ? 'Update available' : 'Update required',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  if (updateType == UpdateType.optional) ...[
                    Text(
                      description ??
                          'To get the most out of the app and enjoy the latest improvements, please update to the newest version.',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),
                  ] else ...[
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0x80151920),
                          height: 1.4,
                        ),
                        text: description ??
                            'To continue using Defyx, please update to the latest version. This update includes critical improvements and is required for app functionality.',
                      ),
                    ),
                  ],
                  if (updateType == UpdateType.optional && features != null) ...[
                    SizedBox(height: 16.h),
                    ...features.map((feature) => Padding(
                          padding: EdgeInsets.only(bottom: 8.h),
                          child: _buildFeatureItem(feature),
                        )),
                  ],
                  SizedBox(height: 20.h),
                  SizedBox(
                    width: double.infinity,
                    height: 44.h,
                    child: ElevatedButton(
                      onPressed: () async {
                        final String url;
                        switch (GlobalVars.appBuildType) {
                          case 'testFlight':
                            url = GlobalVars.testFlight;
                            break;
                          case 'appStore':
                            url = GlobalVars.appStore;
                            break;
                          case 'googlePlay':
                            url = GlobalVars.googlePlay;
                            break;
                          case 'github':
                            url = GlobalVars.github;
                            break;
                          default:
                            url = GlobalVars.github;
                            break;
                        }
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                        // Implement the update logic here, e.g., open app store or download page
                        // Navigator.of(context).pop(true),
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF21AD86),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        'Update now',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (updateType == UpdateType.optional) ...[
                    SizedBox(height: 8.h),
                    SizedBox(
                      width: double.infinity,
                      height: 44.h,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF5F5F5),
                          foregroundColor: Colors.black54,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          'Not now',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildFeatureItem(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppIcons.checkCircle(
          width: 20.w,
          height: 20.h,
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class CustomUpdateDialogAlternative {
  static Future<bool?> showUpdateDialog(
    BuildContext context, {
    required UpdateType updateType,
    List<dynamic>? features,
    String? description,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: updateType == UpdateType.optional,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          content: Container(
            width: 343.w,
            padding: EdgeInsets.only(left: 31.w, right: 31.w, top: 24.h, bottom: 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  updateType == UpdateType.optional ? 'Update available' : 'Update required',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
