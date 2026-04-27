import 'dart:io';

import 'package:defyx_vpn/app/ad_director_provider.dart';
import 'package:defyx_vpn/modules/core/vpn.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/modules/core/desktop_platform_handler.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/update_dialog_handler.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/scroll_manager.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/secret_tap_handler.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/privacy_notice_dialog.dart';
import 'package:defyx_vpn/modules/main/application/main_screen_provider.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/connection_button.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads_widget.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/ads_state.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/dino.dart';
import 'package:defyx_vpn/modules/settings/providers/settings_provider.dart';
import 'package:defyx_vpn/shared/layout/main_screen_background.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/header_section.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/tips_slider_section.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/providers/ad_readiness_coordinator.dart';
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
  late MainScreenLogic _logic;
  late final AdsWidget _adsWidget;
  late ScrollManager _scrollManager;
  late SecretTapHandler _secretTapHandler;

  DinoGame? _dinoGame;

  @override
  void initState() {
    super.initState();
    _logic = MainScreenLogic(ref);
    _scrollManager = ScrollManager(_scrollController);
    _secretTapHandler = SecretTapHandler();

    _adsWidget = AdsWidget(
      backgroundColor: const Color(0xFF19312F),
      cornerRadius: 10.0.r,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _logic.checkAndReconnect();
      
      // Check if privacy notice should be shown using coordinator
      final adReadiness = ref.read(adReadinessCoordinatorProvider);
      if (adReadiness.canShowPrivacyDialog) {
        _showPrivacyNoticeDialog();
      }
      
      _checkInitialConnectionState();

      if (!(Platform.isAndroid || Platform.isIOS)) {
        await _logic.triggerAutoConnectIfEnabled();
      }
      if (mounted) {
        UpdateDialogHandler.checkAndShowUpdates(context, _logic.checkForUpdate);
      }
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

  void _checkInitialConnectionState() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;

      final connectionState = ref.read(connectionStateProvider);
      _previousConnectionStatus = connectionState.status;

      final newShadowState =
          connectionState.status == ConnectionStatus.connected;
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
    PrivacyNoticeDialog.show(context, () async {
      if (ref.context.mounted) {
        // 1. Prepare VPN profile
        final vpnBridge = VpnBridge();
        final result = await vpnBridge.prepareVpn();
        
        if (result && ref.context.mounted) {
          // 2. Initialize VPN
          final vpn = VPN(ProviderScope.containerOf(ref.context));
          await vpn.initVPN();
          
          // 3. Save settings
          await ref.read(settingsProvider.notifier).saveState();
          
          // 4. Mark privacy accepted in coordinator (replaces old scattered state)
          await ref
              .read(adReadinessCoordinatorProvider.notifier)
              .markPrivacyAccepted();
          
          debugPrint('✅ Privacy accepted - coordinator will handle ad init');

          if (!(Platform.isAndroid || Platform.isIOS)) {
            await _logic.triggerAutoConnectIfEnabled();
          }
          return true;
        }
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final adsState = ref.watch(adsProvider);

    if (!(Platform.isAndroid || Platform.isIOS)) {
      ref.listen<int>(trayConnectionToggleTriggerProvider, (previous, next) {
        if (previous != next && next > 0) {
          _logic.connectOrDisconnect();
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _previousConnectionStatus != connectionState.status) {
        _previousConnectionStatus = connectionState.status;
        _handleConnectionStateChange(connectionState.status);
      }
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
                            onTap:
                                connectionState.status ==
                                        ConnectionStatus.loading ||
                                    connectionState.status ==
                                        ConnectionStatus.disconnecting
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
                              height: 50.h,
                            ), // Reduced to raise ads higher
                            SizedBox(
                              height: 0.16.sh,
                            ), // Reduced to raise ads higher
                            _buildContentSection(
                              connectionState.status,
                              adsState,
                            ),
                            SizedBox(
                              height: 0.15.sh,
                            ), // Consistent bottom spacing
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
                      duration: _animationService.adjustDuration(
                        const Duration(milliseconds: 300),
                      ),
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
    // Use hasActiveAdProvider as single source of truth for ad visibility
    final hasActiveAd = ref.watch(hasActiveAdProvider);

    bool shouldShowAd = hasActiveAd;
    Widget? alternativeContent;

    // Build alternative content for when ad is not shown
    switch (status) {
      case ConnectionStatus.noInternet:
        _dinoGame ??= DinoGame();
        alternativeContent = Center(
          child: SizedBox(
            height: 200.h,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: GameWidget(game: _dinoGame!),
            ),
          ),
        );
        break;

      case ConnectionStatus.disconnected:
        // DISCONNECTED: Show tips if no ad available
        if (!hasActiveAd) {
          alternativeContent = TipsSliderSection(status: status);
        }
        break;

      default:
        // CONNECTED/CONNECTING: Show nothing if no ad
        if (!hasActiveAd) {
          alternativeContent = const SizedBox.shrink();
        }
    }

    // CRITICAL: Always use the EXACT same fixed-height container
    // This prevents header from moving when content changes
    return SizedBox(
      height: 330.h, // Fixed height - NEVER changes
      child: Padding(
        padding: EdgeInsets.only(top: 50.h),
        child: SizedBox(
          height: 280.h,
          width: 336.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ad container with dark background - only visible when ad is loaded
              AnimatedOpacity(
                duration: _animationService.adjustDuration(
                  const Duration(milliseconds: 300),
                ),
                opacity: shouldShowAd ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !shouldShowAd,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF19312F),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: _adsWidget,
                  ),
                ),
              ),
              // Alternative content - fades in when ad is hidden
              if (alternativeContent != null)
                AnimatedOpacity(
                  duration: _animationService.adjustDuration(
                    const Duration(milliseconds: 300),
                  ),
                  opacity: shouldShowAd ? 0.0 : 1.0,
                  child: IgnorePointer(
                    ignoring: shouldShowAd,
                    child: alternativeContent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
