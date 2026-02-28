import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/connection_state_widgets.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';

class HeaderSection extends ConsumerWidget {
  final VoidCallback onSecretTap;
  final VoidCallback? onPingRefresh;

  const HeaderSection({
    super.key,
    required this.onSecretTap,
    this.onPingRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: GestureDetector(
                    onTap: onSecretTap,
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'D',
                            style: TextStyle(
                              fontSize: 35.sp,
                              fontFamily: 'Lato',
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFFC927),
                            ),
                          ),
                          TextSpan(
                            text: 'efyx ',
                            style: TextStyle(
                              fontSize: 32.sp,
                              fontFamily: 'Lato',
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFFFFC927),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: ConnectionStatusText(),
                ),
              ],
            ),
            ConnectionStateWidget(onPingRefresh: onPingRefresh),
            SizedBox(height: 8.h),
            AnalyzingStatus(),
          ],
        ),
      ],
    );
  }
}

class ConnectionStatusText extends ConsumerWidget {
  const ConnectionStatusText({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionStateProvider);
    final text = _getStatusText(context, connectionState.status);

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>(text),
        duration: const Duration(milliseconds: 300),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.9 + (0.1 * value),
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: 32.sp,
                  fontFamily: 'Lato',
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getStatusText(BuildContext context, ConnectionStatus status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case ConnectionStatus.loading:
      case ConnectionStatus.connected:
      case ConnectionStatus.analyzing:
        return l10n.statusIs;
      case ConnectionStatus.error:
        return l10n.statusFailed;
      case ConnectionStatus.noInternet:
        return l10n.statusHas;
      case ConnectionStatus.disconnecting:
        return l10n.statusIsReturning;
      default:
        return l10n.statusIsChilling;
    }
  }
}

class ConnectionStateWidget extends ConsumerWidget {
  final VoidCallback? onPingRefresh;

  const ConnectionStateWidget({super.key, this.onPingRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionStateProvider);
    final stateInfo = _getConnectionStateInfo(context, connectionState.status);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.2),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey<String>(connectionState.status.name),
        alignment: AlignmentDirectional.centerStart,
        child: StateSpecificWidget(
          status: connectionState.status,
          text: stateInfo.text,
          color: stateInfo.color,
          fontSize: 32.sp,
          onPingRefresh: onPingRefresh,
        ),
      ),
    );
  }

  ({String text, Color color}) _getConnectionStateInfo(
    BuildContext context,
    ConnectionStatus status,
  ) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case ConnectionStatus.disconnecting:
        return (text: l10n.statusToStandbyMode, color: Colors.white);
      case ConnectionStatus.loading:
        return (text: l10n.statusPluggingIn, color: Colors.white);
      case ConnectionStatus.connected:
        return (text: l10n.statusPoweredUp, color: const Color(0xFFB2FFB9));
      case ConnectionStatus.analyzing:
        return (text: l10n.statusDoingScience, color: Colors.white);
      case ConnectionStatus.noInternet:
        return (text: l10n.statusExitedMatrix, color: const Color(0xFFFFC0C0));
      case ConnectionStatus.error:
        return (text: l10n.statusSorry, color: Colors.white);
      default:
        return (text: l10n.statusConnectAlready, color: Colors.white);
    }
  }
}

class StateSpecificWidget extends StatelessWidget {
  final ConnectionStatus status;
  final String text;
  final Color color;
  final double fontSize;
  final VoidCallback? onPingRefresh;

  const StateSpecificWidget({
    super.key,
    required this.status,
    required this.text,
    required this.color,
    required this.fontSize,
    this.onPingRefresh,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ConnectionStatus.noInternet:
        return NoInternetWidget(
          text: text,
          textColor: color,
          fontSize: fontSize,
        );
      case ConnectionStatus.connected:
        return ConnectedWidget(
          text: text,
          textColor: color,
          fontSize: fontSize,
          onPingRefresh: onPingRefresh,
        );
      default:
        return DefaultStateWidget(
          text: text,
          textColor: color,
          fontSize: fontSize,
          status: status,
        );
    }
  }
}

class AnalyzingStatus extends ConsumerWidget {
  const AnalyzingStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStateProvider).status;
    final isAnalyzing = status == ConnectionStatus.analyzing;

    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: AlignmentDirectional.centerStart,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isAnalyzing ? 1.0 : 0.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: isAnalyzing ? 1.0 : 0.9,
          alignment: Alignment.centerLeft,
          child: isAnalyzing
              ? AnalyzingContent()
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
