import 'package:defyx_vpn/core/theme/app_colors.dart';
import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/modules/core/flow_line_controller.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/defyx_navbar.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/tips_widget.dart';
import 'package:defyx_vpn/shared/providers/flow_line_provider.dart';
import 'package:defyx_vpn/modules/main/application/main_screen_provider.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/connection_button.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/logs_widget.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/google_ads.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/shimmer.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/dino.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/providers/logs_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flame/game.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showHeaderShadow = false;
  int _secretTapCounter = 0;
  DateTime? _lastTapTime;
  ConnectionStatus? _previousConnectionStatus;
  bool? _previousShowCountdown;
  late MainScreenLogic _logic;

  @override
  void initState() {
    super.initState();
    _logic = MainScreenLogic(ref);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logic.checkAndReconnect();
      _logic.checkAndShowPrivacyNotice(_showPrivacyNoticeDialog);
      _checkInitialConnectionState();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final connectionState = ref.read(connectionStateProvider);
    if (_previousConnectionStatus != connectionState.status) {
      _previousConnectionStatus = connectionState.status;
      _handleConnectionStateChange(connectionState.status);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleConnectionStateChange(ConnectionStatus status) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (status == ConnectionStatus.connected) {
        setState(() {
          _showHeaderShadow = true;
        });
        _scrollToBottomWithRetry();
      } else {
        setState(() {
          _showHeaderShadow = false;
        });
        _scrollToTopWithRetry();
      }
    });
  }

  void _handleAdsStateChange(bool showCountdown) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!showCountdown) {
        _scrollToTopWithRetry();
      }
    });
  }

  void _scrollToBottomWithRetry({int attempts = 3}) {
    if (attempts <= 0) return;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
      );
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollToBottomWithRetry(attempts: attempts - 1);
      });
    }
  }

  void _scrollToTopWithRetry({int attempts = 3}) {
    if (attempts <= 0) return;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
      );
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollToTopWithRetry(attempts: attempts - 1);
      });
    }
  }

  void _checkInitialConnectionState() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      final connectionState = ref.read(connectionStateProvider);
      _previousConnectionStatus = connectionState.status;

      if (connectionState.status == ConnectionStatus.connected) {
        setState(() {
          _showHeaderShadow = true;
        });

        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
          );
        }
      } else {
        setState(() {
          _showHeaderShadow = false;
        });

        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  void _handleSecretTap() {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inSeconds > 3) {
      _secretTapCounter = 0;
    }
    _lastTapTime = now;
    _secretTapCounter++;
    if (_secretTapCounter >= 7) {
      Vibration.vibrate(duration: 100);
      _secretTapCounter = 0;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: const Color.fromARGB(13, 0, 0, 0),
              child: const LogScreen(),
            ),
          );
        },
      );
    }
  }

  void _showPrivacyNoticeDialog() {
    final screenWidth = 1.sw;
    const double baseScreenWidth = 375.0;
    final ratio = screenWidth / baseScreenWidth;
    final containerWidth = (300.0 * ratio).clamp(240.0, 390.0).toDouble();
    final fontSize = (16.0 * ratio).clamp(14.0, 18.0).toDouble();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.r),
          ),
          child: Container(
            width: containerWidth,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Privacy Notice',
                  style: TextStyle(
                    fontFamily: 'Lato',
                    fontSize: fontSize * 1.4,
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'This app does not collect any user data or send any information to its servers.\n'
                  'Only some non-personal information (such as the name of your internet provider) '
                  'is stored locally on your device solely to improve connection performance in future attempts.\n'
                  'No personal data is collected, stored, or shared.',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontFamily: 'Lato',
                    color: Colors.black.withOpacity(0.5),
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 20.h),
                ElevatedButton(
                  onPressed: () async {
                    await _logic.markPrivacyNoticeShown();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Got it',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      color: const Color(0xFFF4B4B4B),
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // UI --------

  Widget _buildBackground({required Widget child}) {
    final connectionState = ref.watch(connectionStateProvider).status;

    return Scaffold(
      extendBody: true,
      appBar:
          connectionState == ConnectionStatus.connected
              ? AppBar(
                backgroundColor: Colors.black,
                elevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle.light,
                toolbarHeight: 0,
              )
              : null,
      bottomNavigationBar: const DefyxNavBar(),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                connectionState == ConnectionStatus.disconnected
                    ? [
                      AppColors.topGradient,
                      AppColors.middleGradient,
                      AppColors.bottomGradient,
                    ]
                    : connectionState == ConnectionStatus.connected
                    ? [AppColors.topGradient, AppColors.bottomGradientConnected]
                    : connectionState == ConnectionStatus.noInternet
                    ? [
                      AppColors.topGradient,
                      AppColors.middleGradientNoInternet,
                      AppColors.bottomGradientNoInternet,
                    ]
                    : connectionState == ConnectionStatus.error
                    ? [
                      AppColors.topGradient,
                      AppColors.middleGradientFailedToConnect,
                      AppColors.bottomGradientFailedToConnect,
                    ]
                    : [
                      AppColors.topGradient,
                      AppColors.middleGradient,
                      AppColors.bottomGradient,
                    ],
            stops:
                connectionState == ConnectionStatus.connected
                    ? const [0.0, 1.0]
                    : const [0.2, 0.7, 1.0],
          ),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final adsState = ref.watch(googleAdsProvider);

    if (_previousConnectionStatus != connectionState.status) {
      _previousConnectionStatus = connectionState.status;
      Future.microtask(() {
        _handleConnectionStateChange(connectionState.status);
      });
    }

    if (_previousShowCountdown != null &&
        _previousShowCountdown! &&
        !adsState.showCountdown) {
      Future.microtask(() {
        _handleAdsStateChange(adsState.showCountdown);
      });
    }
    _previousShowCountdown = adsState.showCountdown;

    return _buildBackground(
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 393.w),
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 130.h,
                          child: ConnectionButton(
                            onTap: _logic.connectOrDisconnect,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: 45.h),
                            _buildHeaderSection(),
                            SizedBox(
                              height:
                                  connectionState.status ==
                                          ConnectionStatus.connected
                                      ? 40.h
                                      : 80.h,
                            ),
                            SizedBox(
                              height:
                                  connectionState.status ==
                                          ConnectionStatus.connected
                                      ? 0.24.sh
                                      : 0.3.sh,
                            ),
                            connectionState.status ==
                                    ConnectionStatus.noInternet
                                ? SizedBox(
                                  height: 200.h,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16.r),
                                    child: GameWidget(game: DinoGame()),
                                  ),
                                )
                                : connectionState.status ==
                                    ConnectionStatus.disconnected
                                ? Column(
                                  children: [
                                    SizedBox(height: 0.05.sh),

                                    const TipsSlider(),
                                  ],
                                )
                                : AnimatedSlide(
                                  offset: Offset(
                                    0,
                                    connectionState.status ==
                                                ConnectionStatus.connected &&
                                            adsState.showCountdown
                                        ? 0.0
                                        : 1.0,
                                  ),
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeOut,
                                  child: AnimatedOpacity(
                                    opacity:
                                        connectionState.status ==
                                                    ConnectionStatus
                                                        .connected &&
                                                adsState.showCountdown
                                            ? 1.0
                                            : 0.0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeIn,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF19312F),
                                        borderRadius: BorderRadius.circular(
                                          10.r,
                                        ),
                                      ),
                                      child: GoogleAds(
                                        backgroundColor: const Color(
                                          0xFF19312F,
                                        ),
                                        cornerRadius: 10.0.r,
                                      ),
                                    ),
                                  ),
                                ),
                            SizedBox(height: 0.15.sh),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _showHeaderShadow ? 1.0 : 0.0,
                      child: Container(
                        height: 150.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.black.withOpacity(0.0),
                            ],
                            stops: const [0.0, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => _handleSecretTap(),
                  child: Text(
                    'D',
                    style: TextStyle(
                      fontSize: 35.sp,
                      fontFamily: 'Lato',
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFFC927),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _handleSecretTap(),
                  child: Text(
                    'efyx ',
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontFamily: 'Lato',
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFFFFC927),
                    ),
                  ),
                ),
                _buildConnectionStatusText(),
              ],
            ),
            _buildConnectionStateWidget(),
            SizedBox(height: 8.h),
            _buildAnalyzingStatus(),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectionStatusText() {
    return Consumer(
      builder: (context, ref, child) {
        final connectionState = ref.watch(connectionStateProvider);
        final text = _getStatusText(connectionState.status);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: _buildSlideTransition,
          child: Text(
            text,
            key: ValueKey<String>(text),
            style: TextStyle(
              fontSize: 32.sp,
              fontFamily: 'Lato',
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  String _getStatusText(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.loading:
      case ConnectionStatus.connected:
      case ConnectionStatus.analyzing:
        return 'is';
      case ConnectionStatus.error:
        return 'is failed.';
      case ConnectionStatus.noInternet:
        return 'has';
      default:
        return 'is chilling.';
    }
  }

  Widget _buildSlideTransition(Widget child, Animation<double> animation) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-0.5, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  Widget _buildConnectionStateWidget() {
    return Consumer(
      builder: (context, ref, child) {
        final connectionState = ref.watch(connectionStateProvider);
        final stateInfo = _getConnectionStateInfo(connectionState.status);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: _buildSlideTransition,
          child: _buildStateSpecificWidget(
            connectionState.status,
            stateInfo.text,
            stateInfo.color,
            32.sp,
          ),
        );
      },
    );
  }

  ({String text, Color color}) _getConnectionStateInfo(
    ConnectionStatus status,
  ) {
    switch (status) {
      case ConnectionStatus.loading:
        return (text: 'plugging in ...', color: Colors.white);
      case ConnectionStatus.connected:
        return (text: 'powered up', color: const Color(0xFFB2FFB9));
      case ConnectionStatus.analyzing:
        return (text: 'doing science ...', color: Colors.white);
      case ConnectionStatus.noInternet:
        return (text: 'exited the matrix', color: const Color(0xFFFFC0C0));
      case ConnectionStatus.error:
        return (text: "we're sorry :(", color: Colors.white);
      default:
        return (text: 'Connect already', color: Colors.white);
    }
  }

  Widget _buildStateSpecificWidget(
    ConnectionStatus status,
    String text,
    Color textColor,
    double fontSize,
  ) {
    switch (status) {
      case ConnectionStatus.noInternet:
        return _buildNoInternetWidget(text, textColor, fontSize);
      case ConnectionStatus.connected:
        return _buildConnectedWidget(text, textColor, fontSize);
      default:
        return _buildDefaultStateWidget(text, textColor, fontSize, status);
    }
  }

  Widget _buildNoInternetWidget(String text, Color textColor, double fontSize) {
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

  Widget _buildConnectedWidget(String text, Color textColor, double fontSize) {
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
              _buildFlagIndicator(),
              SizedBox(width: 10.w),
              AppIcons.wifi(width: 8.w, height: 8.h),
              _buildPingIndicator(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlagIndicator() {
    return Consumer(
      builder: (context, ref, child) {
        final flagAsync = ref.watch(flagProvider);
        return flagAsync.when(
          data:
              (flag) => ClipRRect(
                borderRadius: BorderRadius.circular(6.r),
                child: SvgPicture.asset(
                  'assets/flags/$flag.svg',
                  height: 30.h,
                  fit: BoxFit.fitHeight,
                ),
              ),
          loading:
              () => Shimmer.fromColors(
                baseColor: const Color(0xFF307065),
                highlightColor: const Color(0xFF1B483F),
                enabled: true,
                child: FlagPlaceholder(width: 40.w),
              ),
          error:
              (_, __) => SvgPicture.asset('assets/flags/xx.svg', width: 35.w),
        );
      },
    );
  }

  Widget _buildPingIndicator() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        onTap: _logic.refreshPing,
        child: Consumer(
          builder: (context, ref, child) {
            final pingAsync = ref.watch(pingProvider);

            return pingAsync.when(
              data: (ping) {
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
              loading:
                  () => Shimmer.fromColors(
                    baseColor: const Color(0xFF307065),
                    highlightColor: const Color(0xFF1B483F),
                    enabled: true,
                    child: PingPlaceholder(width: 52.w),
                  ),
              error:
                  (_, __) => Text(
                    '-1 ms',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontFamily: 'Lato',
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDefaultStateWidget(
    String text,
    Color textColor,
    double fontSize,
    ConnectionStatus status,
  ) {
    return Text(
      text,
      key: ValueKey<String>(text),
      style: TextStyle(
        fontSize: fontSize,
        fontFamily: 'Lato',
        fontWeight:
            status == ConnectionStatus.error
                ? FontWeight.w300
                : FontWeight.w400,
        color: textColor,
        height: 0,
      ),
    );
  }

  Widget _buildAnalyzingStatus() {
    final status = ref.watch(connectionStateProvider).status;
    if (status != ConnectionStatus.analyzing) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Consumer(
          builder: (context, ref, child) {
            final flowLineState = ref.watch(flowLineStepProvider);
            final currentStep = flowLineState.step;

            return FutureBuilder<int>(
              future: FlowLineController.getTotalSteps(),
              builder: (context, totalStepsSnapshot) {
                final totalSteps =
                    totalStepsSnapshot.hasData ? totalStepsSnapshot.data! : 0;
                return Text(
                  "${currentStep + 1}/$totalSteps",
                  style: TextStyle(
                    color: const Color(0xFFA7A7A7),
                    fontSize: 16.sp,
                    fontFamily: 'Lato',
                    fontWeight: FontWeight.w300,
                  ),
                );
              },
            );
          },
        ),
        SizedBox(width: 10.w),
        AppIcons.arrowLeft(width: 14.w, height: 14.h),
        SizedBox(width: 10.w),
        _buildLoggerStatus(),
      ],
    );
  }

  Widget _buildLoggerStatus() {
    return Consumer(
      builder: (context, ref, child) {
        final loggerState = ref.watch(loggerStateProvider);
        final statusInfo = _getLoggerStatusInfo(loggerState.status);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: _buildSlideTransition,
          child: Text(
            statusInfo.text,
            key: ValueKey<String>(statusInfo.text),
            style: TextStyle(
              fontSize: 16.sp,
              color: statusInfo.color,
              fontFamily: 'Lato',
            ),
          ),
        );
      },
    );
  }

  ({String text, Color color}) _getLoggerStatusInfo(LoggerStatus status) {
    const defaultColor = Color(0xFFA7A7A7);
    switch (status) {
      case LoggerStatus.scanning:
        return (text: 'CHECKING CLEAN IP', color: defaultColor);
      case LoggerStatus.connecting:
        return (text: 'CONNECTING TO WARP ', color: defaultColor);
      case LoggerStatus.change_method:
        return (text: 'CHANGING METHOD', color: defaultColor);
      default:
        return (text: 'LOADING', color: defaultColor);
    }
  }
}
