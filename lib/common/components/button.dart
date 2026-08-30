import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum AppButtonVariant { primary, secondary, tertiary }

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

    return SizedBox(
      height: config.height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,

        style: ElevatedButton.styleFrom(
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.symmetric(vertical: config.verticalPadding),
          elevation: 0,
          backgroundColor: _backgroundColor,
          disabledBackgroundColor: _backgroundColor,
          foregroundColor: _textColor,
          disabledForegroundColor: _textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
            side: BorderSide(color: _borderColor, width: 1),
          ),
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
                    height: 1,
                  ),
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

      case AppButtonVariant.tertiary:
        return Colors.transparent;
    }
  }

  Color get _textColor {
    switch (variant) {
      case AppButtonVariant.primary:
        return Colors.white;

      case AppButtonVariant.secondary:
        return const Color(0xFF4B4B4B);

      case AppButtonVariant.tertiary:
        return const Color(0xFF4B4B4B);
    }
  }

  Color get _loaderColor {
    switch (variant) {
      case AppButtonVariant.primary:
        return Colors.white;

      case AppButtonVariant.secondary:
        return const Color(0xFF4B4B4B);
      case AppButtonVariant.tertiary:
        return const Color(0xFF9E9E9E);
    }
  }

  Color get _borderColor {
    switch (variant) {
      case AppButtonVariant.primary:
        return Colors.transparent;

      case AppButtonVariant.secondary:
        return Colors.transparent;

      case AppButtonVariant.tertiary:
        return const Color(0xFFEAEAEA);
    }
  }

  _ButtonSizeConfig _getSizeConfig() {
    switch (size) {
      case AppButtonSize.small:
        return _ButtonSizeConfig(
          verticalPadding: 11,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          loaderSize: 16,
          height: 36,
        );

      case AppButtonSize.medium:
        return _ButtonSizeConfig(
          verticalPadding: 15,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          loaderSize: 18,
          height: 46,
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
