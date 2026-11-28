import 'dart:io';

import 'package:defyx_vpn/app/ad_director_provider.dart';
import 'package:defyx_vpn/modules/core/vpn.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/modules/core/desktop_platform_handler.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/update_dialog_handler.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/secret_tap_handler.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/privacy_notice_dialog.dart';
import 'package:defyx_vpn/modules/main/application/main_screen_provider.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/connection_button.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads_widget.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/dino.dart';
import 'package:defyx_vpn/modules/settings/providers/settings_provider.dart';
import 'package:defyx_vpn/shared/providers/premium_provider.dart';
import 'package:defyx_vpn/shared/layout/main_screen_background.dart';
import 'package:defyx_vpn/shared/layout/navbar/defyx_navbar.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/header_section.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/tips_widget.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/providers/ad_readiness_coordinator.dart';
import 'package:defyx_vpn/shared/services/animation_service.dart';
import 'package:defyx_vpn/shared/services/telemetry_consent.dart';
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
  static bool _gatewayVerified = false;

  final AnimationService _animationService = AnimationService();
  bool _showHeaderShadow = false;
  ConnectionStatus? _previousConnectionStatus;
  late MainScreenLogic _logic;
  late final AdsWidget _adsWidget;
  late SecretTapHandler _secretTapHandler;

  DinoGame? _dinoGame;

  @override
  void initState() {
    super.initState();
    _logic = MainScreenLogic(ref);
    _secretTapHandler = SecretTapHandler();

    _adsWidget = AdsWidget(
      backgroundColor: const Color(0xFF19312F),
      cornerRadius: 10.0.r,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // On Windows, verify the DXcore gateway before doing anything else.
      if ((Platform.isWindows || Platform.isLinux) && !_gatewayVerified) {
        _gatewayVerified = true;
        final gatewayOk = await VpnBridge().verifyGateway();
        if (!mounted) return;
        if (!gatewayOk) {
          ref.read(connectionStateProvider.notifier).setCoreDown();
          return;
        }
      }

      _logic.checkAndReconnect();

      // Check if privacy notice should be shown using coordinator
      final adReadiness = ref.read(adReadinessCoordinatorProvider);
      if (adReadiness.canShowPrivacyDialog) {
        _showPrivacyNoticeDialog();
      } else if (TelemetryConsent.isSupported && !TelemetryConsent.isDecided) {
        // Users who accepted an earlier notice were never asked about
        // telemetry, which now stays off until they answer.
        PrivacyNoticeDialog.show(
          context,
          () async => true,
          mentionVpnProfile: false,
        );
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
    if (_dinoGame != null) {
      _dinoGame!.pauseEngine();
      _dinoGame!.onRemove();
      _dinoGame = null;
    }
    super.dispose();
  }

  // The page used to scroll down on connect (pushing the title up) and back
  // up afterwards. The ad box now has a fixed place under the shield, so the
  // page never moves.
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
    final hasActiveAd = ref.watch(hasActiveAdProvider);
    final showTips =
        connectionState.status == ConnectionStatus.disconnected && !hasActiveAd;

    final connectionButtonTop = 130.h;
    final adBox = _adBoxGeometry(
      context,
      shieldTip: connectionButtonTop + ConnectionButton.shieldBottom,
    );

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
          // Full height, so the tips card below is placed from the bottom of
          // the screen rather than from the end of the page content.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 393.w,
              minHeight: double.infinity,
            ),
            child: Stack(
              children: [
                // Never scrolls; it only keeps tall content on short screens
                // from overflowing.
                SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: connectionButtonTop,
                          child: ConnectionButton(
                            onTap:
                                connectionState.status ==
                                        ConnectionStatus.loading ||
                                    connectionState.status ==
                                        ConnectionStatus.disconnecting ||
                                    connectionState.status ==
                                        ConnectionStatus.coreDown
                                ? () {}
                                : _logic.connectOrDisconnect,
                          ),
                        ),
                        // Tall enough to hold the ad box, so the Stack does not
                        // clip it or swallow its taps.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: adBox.top + adBox.height,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(height: 45.h),
                              HeaderSection(
                                onSecretTap: _handleSecretTap,
                                onPingRefresh: _logic.refreshPing,
                              ),
                              SizedBox(height: 50.h),
                              SizedBox(height: 0.16.sh),
                              _buildContentSection(connectionState.status),
                              SizedBox(height: 0.15.sh),
                            ],
                          ),
                        ),
                        Positioned(
                          top: adBox.top,
                          child: _buildAdBox(adBox.height),
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
                // Sits a fixed gap above the nav bar on every device.
                if (showTips)
                  Positioned(
                    left: 24.w,
                    right: 24.w,
                    bottom: DefyxNavBar.coveredHeight(context) + 15.h,
                    child: const TipsSlider(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Where the ad box goes, in the coordinates of the page under the status
  /// bar.
  ///
  /// It hangs just below the shield, at the same spot in every state, so the
  /// page never has to move. (It used to follow the header, which grows by
  /// the flag/ping row once connected, and the page scrolled to keep it
  /// above the nav bar.) On short screens it shrinks, and only past that
  /// rises, to stay clear of the nav bar.
  ({double top, double height}) _adBoxGeometry(
    BuildContext context, {
    required double shieldTip,
  }) {
    final preferredTop = shieldTip + 8.h;
    final bottomLimit =
        MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).top -
        DefyxNavBar.coveredHeight(context) -
        8.h;
    final fullHeight = 280.h;
    // Shrink first: the AdMob card appears just as the user taps the shield
    // (to connect), so it shouldn't sit over the shield. Both AdMob layouts
    // (Android's template override, iOS's DefyxNativeAdFactory) and the
    // in-house pictures fit any height.
    final height = (bottomLimit - preferredTop).clamp(200.h, fullHeight);
    // Rise to clear the nav bar, but never over more than the bottom quarter
    // of the shield.
    final top = (bottomLimit - height).clamp(
      shieldTip - ConnectionButton.shieldSize / 4,
      preferredTop,
    );
    return (top: top, height: height);
  }

  bool get _shouldShowAd =>
      ref.watch(hasActiveAdProvider) && ref.watch(adsAllowedProvider);

  /// What sits under the header when no ad is showing (the dino game while
  /// offline).
  Widget _buildContentSection(ConnectionStatus status) {
    if (status != ConnectionStatus.noInternet || _shouldShowAd) {
      return const SizedBox.shrink();
    }
    _dinoGame ??= DinoGame();
    return SizedBox(
      height: 200.h,
      // The game is touch-only. Flame's GameWidget would otherwise grab
      // focus and swallow every key (D-pad and Back included).
      child: ExcludeFocus(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: GameWidget(game: _dinoGame!, autofocus: false),
        ),
      ),
    );
  }

  Widget _buildAdBox(double height) {
    final shouldShowAd = _shouldShowAd;

    // CRITICAL: Keep AdsWidget in ONE position in the tree to prevent
    // dispose/recreate cycles; visibility fades with AnimatedOpacity.
    // Ads are kept out of D-pad focus: the ad is a platform view that would
    // be an invisible focus stop for remote users.
    return ExcludeFocus(
      child: AnimatedOpacity(
        duration: _animationService.adjustDuration(
          const Duration(milliseconds: 300),
        ),
        opacity: shouldShowAd ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !shouldShowAd, // Prevent touch events when hidden
          child: SizedBox(
            height: height,
            width: 336.w,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF19312F),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: _adsWidget, // Always same widget instance, same position
            ),
          ),
        ),
      ),
    );
  }
}
