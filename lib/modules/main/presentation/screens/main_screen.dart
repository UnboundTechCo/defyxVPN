import 'package:defyx_vpn/modules/core/vpn.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/update_dialog_handler.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/scroll_manager.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/secret_tap_handler.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/privacy_notice_dialog.dart';
import 'package:defyx_vpn/modules/main/application/main_screen_provider.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/connection_button.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/google_ads.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/dino.dart';
import 'package:defyx_vpn/shared/layout/main_screen_background.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/header_section.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/tips_slider_section.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/services/animation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final ScrollController _scrollController = ScrollController();
  final AnimationService _animationService = AnimationService();
  bool _showHeaderShadow = false;
  ConnectionStatus? _previousConnectionStatus;
  bool? _previousShowCountdown;
  late MainScreenLogic _logic;
  late final GoogleAds _googleAds;
  late ScrollManager _scrollManager;
  late SecretTapHandler _secretTapHandler;

  DinoGame? _dinoGame;

  @override
  void initState() {
    super.initState();
    _logic = MainScreenLogic(ref);
    _scrollManager = ScrollManager(_scrollController);
    _secretTapHandler = SecretTapHandler();

    _googleAds = GoogleAds(
      backgroundColor: const Color(0xFF19312F),
      cornerRadius: 10.0.r,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logic.checkAndReconnect();
      _logic.checkAndShowPrivacyNotice(_showPrivacyNoticeDialog);
      _checkInitialConnectionState();

      UpdateDialogHandler.checkAndShowUpdates(context, _logic.checkForUpdate);
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
    if (_dinoGame != null) {
      _dinoGame!.pauseEngine();
      _dinoGame!.onRemove();
      _dinoGame = null;
    }
    super.dispose();
  }

  void _handleConnectionStateChange(ConnectionStatus status) {
    // CRITICAL FIX: Check if widget is still mounted before setState
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      final newShadowState = status == ConnectionStatus.connected;
      if (_showHeaderShadow != newShadowState) {
        setState(() {
          _showHeaderShadow = newShadowState;
        });
      }

      if (status == ConnectionStatus.connected) {
        _scrollManager.scrollToBottomWithRetry();
      } else {
        _scrollManager.scrollToTopWithRetry();
      }
    });
  }

  void _handleAdsStateChange(bool showCountdown) {
    _scrollManager.handleAdsStateChange(showCountdown);
  }

  void _checkInitialConnectionState() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;

      final connectionState = ref.read(connectionStateProvider);
      _previousConnectionStatus = connectionState.status;

      final newShadowState = connectionState.status == ConnectionStatus.connected;
      if (_showHeaderShadow != newShadowState) {
        setState(() {
          _showHeaderShadow = newShadowState;
        });
      }

      _scrollManager.checkInitialConnectionState(connectionState.status);
    });
  }

  void _handleSecretTap() {
    _secretTapHandler.handleSecretTap(context);
  }

  void _showPrivacyNoticeDialog() {
    PrivacyNoticeDialog.show(
      context,
      () async {
        if (ref.context.mounted) {
          final vpnBridge = VpnBridge();
          final result = await vpnBridge.prepareVpn();
          if (result && ref.context.mounted) {
            final vpn = VPN(ProviderScope.containerOf(ref.context));
            await vpn.initVPN();
            await _logic.markPrivacyNoticeShown();
            return true;
          }
        }
        return false;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final adsState = ref.watch(googleAdsProvider);

    // CRITICAL FIX: Only handle state changes when actually different
    // This prevents infinite rebuild loops that crash Samsung devices
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _previousConnectionStatus != connectionState.status) {
        _previousConnectionStatus = connectionState.status;
        _handleConnectionStateChange(connectionState.status);
      }

      if (mounted &&
          _previousShowCountdown != null &&
          _previousShowCountdown != adsState.showCountdown &&
          _previousShowCountdown! &&
          !adsState.showCountdown) {
        _handleAdsStateChange(adsState.showCountdown);
      }
      _previousShowCountdown = adsState.showCountdown;
    });

    return MainScreenBackground(
      connectionStatus: connectionState.status,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
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
                            onTap: connectionState.status == ConnectionStatus.loading ||
                                    connectionState.status == ConnectionStatus.disconnecting
                                ? () {}
                                : _logic.connectOrDisconnect,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: 45.h),
                            HeaderSection(
                              onSecretTap: _handleSecretTap,
                              onPingRefresh: _logic.refreshPing,
                            ),
                            SizedBox(
                              height: connectionState.status == ConnectionStatus.connected
                                  ? 40.h
                                  : 80.h,
                            ),
                            SizedBox(
                              height: connectionState.status == ConnectionStatus.connected
                                  ? 0.24.sh
                                  : 0.28.sh,
                            ),
                            _buildContentSection(connectionState.status, adsState),
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
                      duration: _animationService.adjustDuration(const Duration(milliseconds: 300)),
                      opacity: _showHeaderShadow ? 1.0 : 0.0,
                      child: Container(
                        height: 150.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.7),
                              Colors.black.withValues(alpha: 0.0),
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

  Widget _buildContentSection(ConnectionStatus status, dynamic adsState) {
    switch (status) {
      case ConnectionStatus.noInternet:
        _dinoGame ??= DinoGame();
        return SizedBox(
          height: 200.h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: GameWidget(game: _dinoGame!),
          ),
        );

      case ConnectionStatus.disconnected:
        return TipsSliderSection(
          status: status,
        );

      default:
        final shouldShowAd = status == ConnectionStatus.connected && adsState.showCountdown;

        return SizedBox(
          height: 280.h,
          width: 336.w,
          child: AnimatedSlide(
            offset: Offset(
              0,
              shouldShowAd ? 0.0 : 1.0,
            ),
            duration: _animationService.adjustDuration(const Duration(milliseconds: 800)),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: shouldShowAd ? 1.0 : 0.0,
              duration: _animationService.adjustDuration(const Duration(milliseconds: 500)),
              curve: Curves.easeInOut,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF19312F),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: _googleAds,
              ),
            ),
          ),
        );
    }
  }
}
