import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum AppButtonVariant { primary, secondary }

enum AppButtonSize { small, medium }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getSizeConfig();

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        maximumSize: Size(double.infinity, config.height),
        backgroundColor: _backgroundColor,
        disabledBackgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        disabledForegroundColor: _textColor,
        padding: EdgeInsets.symmetric(vertical: config.verticalPadding),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isLoading
            ? SizedBox(
                key: const ValueKey('loader'),
                height: config.loaderSize,
                width: config.loaderSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_loaderColor),
                ),
              )
            : Text(
                label,
                key: const ValueKey('text'),
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: config.fontSize,
                  fontWeight: config.fontWeight,
                  color: _textColor,
                ),
              ),
      ),
    );
  }

  Color get _backgroundColor {
    switch (variant) {
      case AppButtonVariant.primary:
        return const Color(0xFF21AD86);

      case AppButtonVariant.secondary:
        return const Color(0xFFEAEAEA);
    }
  }

  Color get _textColor {
    switch (variant) {
      case AppButtonVariant.primary:
        return Colors.white;

      case AppButtonVariant.secondary:
        return const Color(0xFF4B4B4B);
    }
  }

  Color get _loaderColor {
    switch (variant) {
      case AppButtonVariant.primary:
        return Colors.white;

      case AppButtonVariant.secondary:
        return const Color(0xFF4B4B4B);
    }
  }

  _ButtonSizeConfig _getSizeConfig() {
    switch (size) {
      case AppButtonSize.small:
        return _ButtonSizeConfig(
          verticalPadding: 6.h,
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          loaderSize: 16.w,
          height: 36.h,
        );

      case AppButtonSize.medium:
        return _ButtonSizeConfig(
          verticalPadding: 11.h,
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
          loaderSize: 18.w,
          height: 46.h,
        );
    }
  }
}

class _ButtonSizeConfig {
  final double verticalPadding;
  final double fontSize;
  final FontWeight fontWeight;
  final double loaderSize;
  final double height;

  const _ButtonSizeConfig({
    required this.verticalPadding,
    required this.fontSize,
    required this.fontWeight,
    required this.loaderSize,
    required this.height,
  });
}
