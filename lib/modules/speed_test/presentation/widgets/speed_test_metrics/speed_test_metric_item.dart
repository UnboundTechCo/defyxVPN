import 'package:defyx_vpn/core/utils/format_number.dart';
import 'package:defyx_vpn/core/theme/app_colors.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/services/animation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

class MetricItemCompact extends StatelessWidget {
  final String label;
  final num value;
  final String unit;
  final ConnectionStatus connectionStatus;

  const MetricItemCompact({
    super.key,
    required this.label,
    required this.value,
    this.unit = 'Mbps',
    required this.connectionStatus,
  });

  Color _getColorByStatus(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return AppColors.bottomGradientConnected;
      case ConnectionStatus.disconnected:
        return AppColors.bottomGradient;
      case ConnectionStatus.noInternet:
        return AppColors.bottomGradientNoInternet;
      case ConnectionStatus.error:
        return AppColors.bottomGradientFailedToConnect;
      case ConnectionStatus.loading:
      case ConnectionStatus.analyzing:
        return AppColors.bottomGradientConnecting;
      default:
        return AppColors.bottomGradient;
    }
  }

  Color _getHighlightColorByStatus(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return AppColors.middleGradientConnected;
      case ConnectionStatus.disconnected:
        return AppColors.middleGradient;
      case ConnectionStatus.noInternet:
        return AppColors.middleGradientNoInternet;
      case ConnectionStatus.error:
        return AppColors.middleGradientFailedToConnect;
      case ConnectionStatus.loading:
      case ConnectionStatus.analyzing:
        return AppColors.middleGradientConnecting;
      default:
        return AppColors.middleGradient;
    }
  }

  @override
  Widget build(BuildContext context) {
    final animationService = AnimationService();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 6.h,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontFamily: 'Lato',
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
        value > 0
            ? RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: numFormatNumber(value),
                      style: TextStyle(
                        fontSize: 26.sp,
                        fontFamily: 'Lato',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: " $unit",
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontFamily: 'Lato',
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
            : Shimmer.fromColors(
                baseColor: _getColorByStatus(connectionStatus),
                highlightColor: _getHighlightColorByStatus(connectionStatus),
                enabled: animationService.shouldAnimate(),
                child: Container(
                  width: 75.w,
                  height: 20.h,
                  decoration: BoxDecoration(
                    color: _getColorByStatus(connectionStatus),
                    borderRadius: BorderRadius.circular(15.r),
                  ),
                ),
              ),
      ],
    );
  }
}

class MetricItemHorizontal extends StatelessWidget {
  final String label;
  final num value;
  final String unit;
  final ConnectionStatus connectionStatus;

  const MetricItemHorizontal({
    super.key,
    required this.label,
    required this.value,
    this.unit = 'Mbps',
    required this.connectionStatus,
  });

  Color _getColorByStatus(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return AppColors.bottomGradientConnected;
      case ConnectionStatus.disconnected:
        return AppColors.bottomGradient;
      case ConnectionStatus.noInternet:
        return AppColors.bottomGradientNoInternet;
      case ConnectionStatus.error:
        return AppColors.bottomGradientFailedToConnect;
      case ConnectionStatus.loading:
      case ConnectionStatus.analyzing:
        return AppColors.bottomGradientConnecting;
      default:
        return AppColors.bottomGradient;
    }
  }

  Color _getHighlightColorByStatus(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return AppColors.middleGradientConnected;
      case ConnectionStatus.disconnected:
        return AppColors.middleGradient;
      case ConnectionStatus.noInternet:
        return AppColors.middleGradientNoInternet;
      case ConnectionStatus.error:
        return AppColors.middleGradientFailedToConnect;
      case ConnectionStatus.loading:
      case ConnectionStatus.analyzing:
        return AppColors.middleGradientConnecting;
      default:
        return AppColors.middleGradient;
    }
  }

  @override
  Widget build(BuildContext context) {
    final animationService = AnimationService();
    final bool hasValue = (label == 'P.LOSS') ? true : value > 0;

    return SizedBox(
      width: 115.w,
      height: 20.h,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            top: 5.h,
            left: 0,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontFamily: 'Lato',
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          hasValue
              ? Positioned(
                  bottom: 0,
                  right: 0,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: numFormatNumber(value),
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontFamily: 'Lato',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: " $unit",
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontFamily: 'Lato',
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Positioned(
                  bottom: 2.5.h,
                  right: 0,
                  child: Shimmer.fromColors(
                    baseColor: _getColorByStatus(connectionStatus),
                    highlightColor: _getHighlightColorByStatus(connectionStatus),
                    enabled: animationService.shouldAnimate(),
                    child: Container(
                      width: 57.w,
                      height: 11.h,
                      decoration: BoxDecoration(
                        color: _getColorByStatus(connectionStatus),
                        borderRadius: BorderRadius.circular(15.r),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
