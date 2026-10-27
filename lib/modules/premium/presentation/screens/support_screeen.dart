import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Need Help?',
                style: TextStyle(
                  fontSize: 18.sp,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Lato',
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Contact our support team through the following channels:',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[700],
                  height: 1.5,
                  fontFamily: 'Lato',
                ),
              ),
              SizedBox(height: 24.h),
              _SupportButton(
                label: 'Telegram',
                icon: Icons.send,
                onTap: () {
                  // Open Telegram support
                },
              ),
              SizedBox(height: 12.h),
              _SupportButton(
                label: 'Email',
                icon: Icons.email,
                onTap: () {
                  // Open email client
                },
              ),
              SizedBox(height: 12.h),
              _SupportButton(
                label: 'Website',
                icon: Icons.language,
                onTap: () {
                  // Open website
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SupportButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.grey[600], size: 20.sp),
                SizedBox(width: 8.w),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
