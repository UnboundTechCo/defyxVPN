import 'dart:ui' show ImageFilter;

import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/shared/services/animation_service.dart';
import 'package:defyx_vpn/shared/tv/tv_support.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Renders one of our own (in-house) ads inside the ad box.
///
/// The whole picture is always visible: it is scaled to fit the box and any
/// space left over is filled with a blurred copy of the same picture, so
/// banners of any aspect ratio look intentional instead of cropped.
///
/// Once the picture is on screen, an [AdClickCue] hangs from the top edge and
/// points down at it. The cue is for in-house ads only: AdMob's policies
/// forbid drawing attention to Google ads with arrows or "click" prompts.
class InternalAdView extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onTap;
  final void Function(Object error) onImageError;
  final Color backgroundColor;

  const InternalAdView({
    super.key,
    required this.imageUrl,
    required this.onTap,
    required this.onImageError,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: backgroundColor),
          // Backdrop for the letterbox bars. Same URL as the picture below, so
          // the image cache serves both from a single download.
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
          Image.network(
            imageUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              final shown = frame != null || wasSynchronouslyLoaded;
              if (!shown || TvSupport.isTv) return child;
              // Remotes cannot reach the ad (it is excluded from D-pad
              // focus), so the cue is only shown where it can be acted on.
              return Stack(
                fit: StackFit.expand,
                children: [
                  child,
                  // Own layer, so the bobbing arrow does not repaint the
                  // blurred backdrop every frame.
                  const Align(
                    alignment: Alignment.topCenter,
                    child: RepaintBoundary(child: AdClickCue()),
                  ),
                ],
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;

              // Spinner on the ad box colour, so the box does not blink.
              return Container(
                color: backgroundColor,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                    color: Colors.green,
                    strokeWidth: 2.0,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              onImageError(error);
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

/// A tab hanging from the top edge of the ad box that invites a tap, with an
/// arrow bobbing down towards the ad.
class AdClickCue extends StatefulWidget {
  const AdClickCue({super.key});

  @override
  State<AdClickCue> createState() => _AdClickCueState();
}

class _AdClickCueState extends State<AdClickCue>
    with SingleTickerProviderStateMixin {
  static const Color _brandYellow = Color(0xFFFFC927);
  static const Color _ink = Color(0xFF19312F);

  final AnimationService _animationService = AnimationService();
  late final AnimationController _bob;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _animationService.conditionalRepeat(_bob, reverse: true);
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isTouch =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final label = isTouch ? l10n.adTapToLearnMore : l10n.adClickToLearnMore;
    final bobDistance = 4.h;

    return Container(
      constraints: BoxConstraints(maxWidth: 300.w),
      padding: EdgeInsets.fromLTRB(14.w, 5.h, 10.w, 6.h),
      decoration: BoxDecoration(
        color: _brandYellow,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12.r),
          bottomRight: Radius.circular(12.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _ink,
                fontSize: 13.sp,
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          AnimatedBuilder(
            animation: _bob,
            builder: (context, child) => Transform.translate(
              offset: Offset(
                0,
                Curves.easeInOut.transform(_bob.value) * bobDistance -
                    bobDistance / 2,
              ),
              child: child,
            ),
            child: Icon(
              Icons.keyboard_double_arrow_down_rounded,
              color: _ink,
              size: 18.sp,
            ),
          ),
        ],
      ),
    );
  }
}
