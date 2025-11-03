import 'package:defyx_vpn/shared/providers/group_provider.dart';
import 'package:defyx_vpn/shared/services/animation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/modules/main/application/main_screen_provider.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/shimmer.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/providers/flow_line_provider.dart';
import 'package:defyx_vpn/shared/providers/logs_provider.dart';

class NoInternetWidget extends StatelessWidget {
  final String text;
  final Color textColor;
  final double fontSize;

  const NoInternetWidget({
    super.key,
    required this.text,
    required this.textColor,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          text,
          key: ValueKey<String>(text),
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: 'Lato',
            fontWeight: FontWeight.w500,
            color: textColor,
            height: 0,
          ),
        ),
        AppIcons.noWifi(width: 20.w, height: 20.h),
      ],
    );
  }
}

class ConnectedWidget extends StatelessWidget {
  final String text;
  final Color textColor;
  final double fontSize;
  final VoidCallback? onPingRefresh;

  const ConnectedWidget({
    super.key,
    required this.text,
    required this.textColor,
    required this.fontSize,
    this.onPingRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          key: ValueKey<String>(text),
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: 'Lato',
            fontWeight: FontWeight.w400,
            color: textColor,
            height: 0,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 15.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FlagIndicator(),
              SizedBox(width: 10.w),
              AppIcons.wifi(width: 8.w, height: 8.h),
              PingIndicator(onRefresh: onPingRefresh),
            ],
          ),
        ),
      ],
    );
  }
}

class FlagIndicator extends ConsumerWidget {
  const FlagIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animationService = AnimationService();
    final flagAsync = ref.watch(flagProvider);
    return flagAsync.when(
      data: (flag) => ClipRRect(
        borderRadius: BorderRadius.circular(6.r),
        child: SvgPicture.asset(
          'assets/flags/$flag.svg',
          height: 30.h,
          fit: BoxFit.fitHeight,
        ),
      ),
      loading: () => Shimmer.fromColors(
        baseColor: const Color(0xFF307065),
        highlightColor: const Color(0xFF1B483F),
        enabled: animationService.shouldAnimate(),
        child: FlagPlaceholder(width: 40.w),
      ),
      error: (_, __) => SvgPicture.asset('assets/flags/xx.svg', width: 35.w),
    );
  }
}

class PingIndicator extends ConsumerWidget {
  final VoidCallback? onRefresh;

  const PingIndicator({super.key, this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animationService = AnimationService();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        onTap: onRefresh,
        child: Consumer(
          builder: (context, ref, child) {
            final ping = ref.watch(pingProvider);
            final pingLoading = ref.watch(pingLoadingProvider);

            if (pingLoading) {
              return Shimmer.fromColors(
                baseColor: const Color(0xFF307065),
                highlightColor: const Color(0xFF1B483F),
                enabled: animationService.shouldAnimate(),
                child: PingPlaceholder(width: 52.w),
              );
            }
            if (ping.isEmpty) {
              return Text(
                '0 ms',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontFamily: 'Lato',
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              );
            }
            return Row(
              children: [
                SizedBox(width: 10.w),
                Text(
                  ping,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontFamily: 'Lato',
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                Text(
                  ' ms',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontFamily: 'Lato',
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class DefaultStateWidget extends StatelessWidget {
  final String text;
  final Color textColor;
  final double fontSize;
  final ConnectionStatus status;

  const DefaultStateWidget({
    super.key,
    required this.text,
    required this.textColor,
    required this.fontSize,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      key: ValueKey<String>(text),
      style: TextStyle(
        fontSize: fontSize,
        fontFamily: 'Lato',
        fontWeight: status == ConnectionStatus.error
            ? FontWeight.w300
            : FontWeight.w400,
        color: textColor,
        height: 0,
      ),
    );
  }
}

class AnalyzingContent extends ConsumerWidget {
  const AnalyzingContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animationService = AnimationService();
    return Row(
      children: [
        Consumer(builder: (context, ref, child) {
          final flowLineState = ref.watch(flowLineStepProvider);
          final currentStep = flowLineState.step;
          final totalSteps = flowLineState.totalSteps;

          if (totalSteps == 0 || currentStep == 0) {
            return Shimmer.fromColors(
              baseColor: const Color(0xFF4161A6),
              highlightColor: const Color(0xFF23499C),
              enabled: animationService.shouldAnimate(),
              child: StepsPlaceholder(width: 40.w),
            );
          }

          return Text(
            "$currentStep/$totalSteps",
            style: TextStyle(
              color: const Color(0xFFA7A7A7),
              fontSize: 16.sp,
              fontFamily: 'Lato',
              fontWeight: FontWeight.w300,
            ),
          );
        }),
        SizedBox(width: 10.w),
        AppIcons.arrowLeft(width: 14.w, height: 14.h),
        SizedBox(width: 10.w),
        LoggerStatusWidget()
      ],
    );
  }
}

class LoggerStatusWidget extends ConsumerWidget {
  const LoggerStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animationService = AnimationService();
    final loggerState = ref.watch(loggerStateProvider);
    final groupState = ref.watch(groupStateProvider);
    final statusInfo =
        _getLoggerStatusInfo(loggerState.status, groupState.groupName);

    return AnimatedSize(
      duration: animationService.adjustDuration(const Duration(milliseconds: 300)),
      curve: Curves.easeInOut,
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>(statusInfo.text),
        duration: animationService.adjustDuration(const Duration(milliseconds: 350)),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          if (loggerState.status == LoggerStatus.loading) {
            return Shimmer.fromColors(
              baseColor: const Color(0xFF4161A6),
              highlightColor: const Color(0xFF23499C),
              enabled: animationService.shouldAnimate(),
              child: StepsPlaceholder(width: 120.w),
            );
          }
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.95 + (0.05 * value),
              alignment: Alignment.centerLeft,
              child: Text(
                statusInfo.text,
                style: TextStyle(
                  fontSize: 16.sp,
                  color: statusInfo.color,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  ({String text, Color color}) _getLoggerStatusInfo(
      LoggerStatus? status, String groupName) {
    const defaultColor = Color(0xFFA7A7A7);
    switch (status) {
      case LoggerStatus.loading:
        return (text: 'LOADING', color: defaultColor);
      case LoggerStatus.connecting:
        if (groupName.isEmpty) {
          return (text: 'CONNECTING', color: defaultColor);
        }
        return (text: 'CONNECTING VIA $groupName ', color: defaultColor);
      case LoggerStatus.switching_method:
        return (text: 'SWITCHING METHOD', color: defaultColor);
      default:
        return (text: 'LOADING', color: defaultColor);
    }
  }
}
