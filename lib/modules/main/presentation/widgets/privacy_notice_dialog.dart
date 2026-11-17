import 'dart:io';

import 'package:defyx_vpn/core/theme/app_colors.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/shared/services/telemetry_consent.dart';
import 'package:defyx_vpn/shared/tv/tv_support.dart';
import 'package:defyx_vpn/shared/utils/tv_keyboard_helper.dart';
import 'package:defyx_vpn/shared/widgets/tv_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Says what the app sends and where, and asks whether usage statistics and
/// crash reports may be sent. Nothing goes to Firebase until the user ticks
/// the box; it starts unticked.
class PrivacyNoticeDialog extends StatefulWidget {
  final Future<bool> Function() onAccept;

  /// Whether to mention the VPN profile. Off when the notice is shown again
  /// to a user who set up the VPN with an earlier version of it.
  final bool mentionVpnProfile;

  const PrivacyNoticeDialog({
    super.key,
    required this.onAccept,
    this.mentionVpnProfile = true,
  });

  @override
  State<PrivacyNoticeDialog> createState() => _PrivacyNoticeDialogState();

  static Future<void> show(
    BuildContext context,
    Future<bool> Function() onAccept, {
    bool mentionVpnProfile = true,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: PrivacyNoticeDialog(
            onAccept: onAccept,
            mentionVpnProfile: mentionVpnProfile,
          ),
        );
      },
    );
  }
}

class _PrivacyNoticeDialogState extends State<PrivacyNoticeDialog> {
  bool _isLoading = false;
  late bool _shareDiagnostics = TelemetryConsent.isGranted;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // On TV the notice text is a focus stop that Up and Down scroll, so a
  // remote can read all of it. At either end the key moves focus on.
  KeyEventResult _scrollNotice(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || !_scroll.hasClients) {
      return KeyEventResult.ignored;
    }
    final direction = TvKeyboardHelper.directionOf(event);
    if (direction != TraversalDirection.up &&
        direction != TraversalDirection.down) {
      return KeyEventResult.ignored;
    }
    final position = _scroll.position;
    final down = direction == TraversalDirection.down;
    final atEnd = down
        ? position.pixels >= position.maxScrollExtent
        : position.pixels <= position.minScrollExtent;
    if (atEnd) return KeyEventResult.ignored;
    final step = position.viewportDimension * 0.6;
    _scroll.animateTo(
      (position.pixels + (down ? step : -step)).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    return KeyEventResult.handled;
  }

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  Future<void> _handleGotIt() async {
    try {
      if (_isLoading) return;
      setState(() => _isLoading = true);

      if (TelemetryConsent.isSupported) {
        await TelemetryConsent.set(_shareDiagnostics);
      }
      final accepted = await widget.onAccept();
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (accepted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error in _handleGotIt: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.of(context).pop();
    }
  }

  String _message(AppLocalizations l10n) {
    final items = [
      l10n.privacyNoticeConnection,
      if (TelemetryConsent.isSupported) l10n.privacyNoticeTelemetry,
      if (_isMobile) l10n.privacyNoticeAds,
      l10n.privacyNoticeSpeedTest,
      l10n.privacyNoticeOwnTraffic,
    ];
    return [
      '${l10n.privacyNoticeIntro}\n${items.join('\n')}',
      l10n.privacyNoticeLocal,
      if (_isMobile && widget.mentionVpnProfile) l10n.privacyNoticeVpnProfile,
    ].join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenWidth = 1.sw;
    const double baseScreenWidth = 375.0;
    final ratio = screenWidth / baseScreenWidth;
    final fontSize = (16.0 * ratio).clamp(14.0, 18.0).toDouble();
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: AppTheme.fontFamily,
      color: Colors.black.withValues(alpha: 0.5),
      height: 1.4,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Container(
        padding: EdgeInsets.all(20.w),
        width: 343.w,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.privacyNoticeTitle,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: fontSize * 1.4,
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 20.h),
            Flexible(
              child: TvFocusable(
                enabled: TvSupport.isTv,
                autofocus: TvSupport.isTv,
                handleTaps: false,
                onKeyEvent: _scrollNotice,
                borderRadius: BorderRadius.circular(6.r),
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Text(_message(l10n), style: textStyle),
                ),
              ),
            ),
            if (TelemetryConsent.isSupported) ...[
              SizedBox(height: 12.h),
              _buildConsentCheckbox(l10n, fontSize),
              Text(
                l10n.privacyNoticeChangeLater,
                style: textStyle.copyWith(fontSize: fontSize * 0.85),
              ),
            ],
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: _handleGotIt,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: const Color.fromARGB(255, 47, 41, 41),
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: const CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.bottomGradientConnected,
                      ),
                    )
                  : Text(
                      l10n.privacyNoticeGotIt,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: const Color(0xFF4B4B4B),
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // One focus stop for the remote: the row toggles, the checkbox itself does
  // not take focus.
  Widget _buildConsentCheckbox(AppLocalizations l10n, double fontSize) {
    return TvFocusable(
      onTap: () => setState(() => _shareDiagnostics = !_shareDiagnostics),
      borderRadius: BorderRadius.circular(6.r),
      child: Row(
        children: [
          ExcludeFocus(
            child: Checkbox(
              value: _shareDiagnostics,
              activeColor: AppColors.bottomGradientConnected,
              onChanged: (value) =>
                  setState(() => _shareDiagnostics = value ?? false),
            ),
          ),
          Expanded(
            child: Text(
              l10n.privacyNoticeShareDiagnostics,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: fontSize,
                color: Colors.black.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
