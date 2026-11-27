import 'dart:io';
import 'dart:math' as math;

import 'package:defyx_vpn/core/theme/app_colors.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/shared/services/telemetry_consent.dart';
import 'package:defyx_vpn/shared/tv/tv_support.dart';
import 'package:defyx_vpn/shared/utils/tv_keyboard_helper.dart';
import 'package:defyx_vpn/shared/widgets/tv_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  // Wide enough for a comfortable line length, never a full-width sheet on
  // tablets, desktop or TV.
  static const double _maxWidth = 420;
  // The dialog leaves part of the screen visible, so it reads as a step on
  // top of the app; the notice scrolls inside it. Short screens (landscape
  // TV, small phones) get a floor so the text area is not a sliver.
  static const double _maxHeightFraction = 0.75;
  static const double _maxHeight = 600;
  static const double _minHeight = 460;

  static const Color _accent = AppColors.bottomGradientConnected;
  static const Color _titleColor = Color(0xDD000000);
  // 6.7:1 and 5.3:1 on white, above the WCAG AA 4.5:1 minimum.
  static const Color _bodyColor = Color(0xFF595959);
  static const Color _hintColor = Color(0xFF6B6B6B);
  static const Color _dividerColor = Color(0xFFE6E6E6);
  static const Color _panelColor = Color(0xFFF4F5F6);

  bool _isLoading = false;
  late bool _shareDiagnostics = TelemetryConsent.isGranted;
  final _scroll = ScrollController();

  // Dividers show only while text is hidden past that edge.
  bool _hiddenAbove = false;
  bool _hiddenBelow = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _onScrollMetrics(ScrollMetrics metrics) {
    final hiddenAbove = metrics.pixels > metrics.minScrollExtent + 0.5;
    final hiddenBelow = metrics.pixels < metrics.maxScrollExtent - 0.5;
    if (hiddenAbove != _hiddenAbove || hiddenBelow != _hiddenBelow) {
      setState(() {
        _hiddenAbove = hiddenAbove;
        _hiddenBelow = hiddenBelow;
      });
    }
    return false; // let the Scrollbar see it too
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

  List<String> _items(AppLocalizations l10n) => [
    l10n.privacyNoticeConnection,
    if (TelemetryConsent.isSupported) l10n.privacyNoticeTelemetry,
    if (_isMobile) l10n.privacyNoticeAds,
    l10n.privacyNoticeSpeedTest,
    l10n.privacyNoticeOwnTraffic,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screen = MediaQuery.sizeOf(context);
    // Scale with the phone width like the rest of the app, but keep body
    // text readable on small phones and modest on tablets, desktop and TV.
    final bodySize = (14.0 * screen.width / 375).clamp(13.5, 16.0).toDouble();
    final body = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: bodySize,
      height: 1.5,
      color: _bodyColor,
    );
    final hint = body.copyWith(fontSize: bodySize * 0.87, color: _hintColor);

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _maxWidth,
          maxHeight: _maxDialogHeight(screen.height),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(l10n, bodySize),
            _edgeDivider(visible: _hiddenAbove),
            Flexible(child: _buildNotice(l10n, body)),
            _edgeDivider(visible: _hiddenBelow),
            _buildFooter(l10n, bodySize, hint),
          ],
        ),
      ),
    );
  }

  double _maxDialogHeight(double screenHeight) {
    final floor = math.min(screenHeight * 0.9, _minHeight);
    return (screenHeight * _maxHeightFraction).clamp(floor, _maxHeight);
  }

  Widget _buildHeader(AppLocalizations l10n, double bodySize) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20, 20, 20, 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.privacy_tip_outlined,
              size: 20,
              color: _accent,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                l10n.privacyNoticeTitle,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: bodySize * 1.3,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: _titleColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _edgeDivider({required bool visible}) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 150),
      child: const ColoredBox(color: _dividerColor, child: SizedBox(height: 1)),
    );
  }

  Widget _buildNotice(AppLocalizations l10n, TextStyle body) {
    final items = _items(l10n);
    return TvFocusable(
      enabled: TvSupport.isTv,
      autofocus: TvSupport.isTv,
      handleTaps: false,
      onKeyEvent: _scrollNotice,
      borderRadius: BorderRadius.circular(6),
      child: Scrollbar(
        controller: _scroll,
        // Always shown, so it is clear from the start that there is more.
        thumbVisibility: true,
        thickness: 4,
        radius: const Radius.circular(2),
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (n) => _onScrollMetrics(n.metrics),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) => _onScrollMetrics(n.metrics),
            child: SingleChildScrollView(
              controller: _scroll,
              // Extra space on the scrollbar side keeps text clear of it.
              padding: EdgeInsetsDirectional.fromSTEB(20, 4, 28, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.privacyNoticeIntro,
                    style: body.copyWith(
                      color: _titleColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 10),
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) SizedBox(height: 10),
                    _bullet(items[i], body),
                  ],
                  SizedBox(height: 16),
                  Text(l10n.privacyNoticeLocal, style: body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Hanging indent: wrapped lines start under the text, not under the dot.
  Widget _bullet(String text, TextStyle style) {
    const dot = 6.0;
    final firstLine = style.fontSize! * style.height!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: (firstLine - dot) / 2),
          child: Container(
            width: dot,
            height: dot,
            decoration: const BoxDecoration(
              color: _accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
        SizedBox(width: 10),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }

  // Fixed below the scrolling text, so the choice and the button are
  // always in reach.
  Widget _buildFooter(AppLocalizations l10n, double bodySize, TextStyle hint) {
    final showVpnProfile = _isMobile && widget.mentionVpnProfile;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20, 14, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (TelemetryConsent.isSupported) ...[
            _buildConsent(l10n, bodySize, hint),
            SizedBox(height: 14),
          ],
          // Right above the button it describes.
          if (showVpnProfile) ...[
            Text(
              l10n.privacyNoticeVpnProfile,
              textAlign: TextAlign.center,
              style: hint,
            ),
            SizedBox(height: 10),
          ],
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleGotIt,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                disabledBackgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      l10n.privacyNoticeGotIt,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: bodySize + 0.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // One focus stop for the remote: the whole panel toggles, the checkbox
  // itself does not take focus. The hint sits under the label it explains.
  Widget _buildConsent(AppLocalizations l10n, double bodySize, TextStyle hint) {
    final label = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: bodySize,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: _titleColor,
    );
    // Centre the label's first line on the 48px checkbox.
    final labelTop = math.max(0.0, (48 - bodySize * 1.4) / 2);
    return Material(
      color: _panelColor,
      borderRadius: BorderRadius.circular(12),
      child: TvFocusable(
        onTap: () => setState(() => _shareDiagnostics = !_shareDiagnostics),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(2, 0, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeFocus(
                child: Checkbox(
                  value: _shareDiagnostics,
                  activeColor: _accent,
                  side: const BorderSide(color: Color(0xFF8A8A8A), width: 1.5),
                  onChanged: (value) =>
                      setState(() => _shareDiagnostics = value ?? false),
                ),
              ),
              SizedBox(width: 2),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: labelTop),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.privacyNoticeShareDiagnostics, style: label),
                      SizedBox(height: 2),
                      Text(l10n.privacyNoticeChangeLater, style: hint),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
