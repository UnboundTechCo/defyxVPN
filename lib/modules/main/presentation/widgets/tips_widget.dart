import 'dart:async';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/shared/providers/hints_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Reports the real, unconstrained size of [child] after every layout pass.
// Manually estimating text height (via TextPainter) proved unreliable across
// languages/fonts (line-height metrics differ per font, mixed-script bidi
// text can wrap differently than a plain LTR measurement predicts); actually
// measuring the on-screen content is the only way to size the card exactly
// right regardless of language.
class _MeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;

  const _MeasureSize({required this.onChange, required Widget super.child});

  @override
  _MeasureSizeRenderObject createRenderObject(BuildContext context) =>
      _MeasureSizeRenderObject(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _MeasureSizeRenderObject renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  ValueChanged<Size> onChange;
  Size? _oldSize;

  _MeasureSizeRenderObject(this.onChange);

  @override
  void performLayout() {
    super.performLayout();
    if (size != _oldSize) {
      _oldSize = size;
      final callback = onChange;
      final newSize = size;
      WidgetsBinding.instance.addPostFrameCallback((_) => callback(newSize));
    }
  }
}

class TipsSlider extends ConsumerStatefulWidget {
  const TipsSlider({super.key});

  @override
  ConsumerState<TipsSlider> createState() => _TipsSliderState();
}

class _TipsSliderState extends ConsumerState<TipsSlider> {
  static const int _maxMessageLines = 6;
  static const double _minHeight = 120.0;
  // AnimatedContainer padding (top 15 + bottom 20) plus the content
  // column's top padding (40) that sits above the measured title/message
  // block. These are plain layout constants, not language-dependent, so
  // they're safe to hardcode - only the text block itself needs measuring.
  static const double _structuralOverhead = 75.0;
  // The card's border; Container adds it inside the height, on top of the
  // padding, so it counts too (leaving it out clipped the last line).
  static const double _borderWidth = 1;

  final Map<int, double> _measuredContentHeights = {};

  // The page state lives and dies with the card, so the page shown, the dots
  // and the height always agree. (Kept app-wide, it survived the card being
  // rebuilt - e.g. on disconnect - while the new PageView started at the
  // first tip, so the card was sized for another tip and cut text off.)
  final PageController _pageController = PageController();
  int _page = 0;
  int _tipCount = 0;
  Timer? _autoAdvance;

  @override
  void initState() {
    super.initState();
    _autoAdvance = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_tipCount < 2 || !_pageController.hasClients) return;
      _pageController.animateToPage(
        (_page + 1) % _tipCount,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onContentMeasured(int index, Size size) {
    if (!mounted) return;
    if (_measuredContentHeights[index] != size.height) {
      setState(() {
        _measuredContentHeights[index] = size.height;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipsAsync = ref.watch(selectedHintsProvider);
    final currentPage = _page;
    final l10n = AppLocalizations.of(context);

    return tipsAsync.when(
      data: (hints) {
        if (hints.isEmpty) {
          return const SizedBox.shrink();
        }

        final tips = hints
            .map((hint) => {'title': hint.title, 'message': hint.message})
            .toList();

        _tipCount = tips.length;
        final pageIndex = currentPage % tips.length;
        final measuredContentHeight = _measuredContentHeights[pageIndex];
        final dynamicHeight = measuredContentHeight == null
            ? _minHeight.h
            : (measuredContentHeight + _structuralOverhead.h + 2 * _borderWidth)
                  .clamp(_minHeight.h, double.infinity);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.only(
            left: 25.w,
            right: 25.w,
            top: 15.h,
            bottom: 20.h,
          ),
          height: dynamicHeight,
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 0, 0, 0).withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.33),
              width: _borderWidth,
            ),
          ),
          child: Stack(
            children: [
              // Main content
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TIPS icon and text
                  Image.asset(
                    'assets/icons/messages.png',
                    width: 33.w,
                    height: 33.h,
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    l10n.tips,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.only(top: 40.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sliding content
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                          },
                        ),
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: tips.length,
                          onPageChanged: (page) {
                            setState(() => _page = page);
                          },
                          itemBuilder: (context, index) {
                            final title = tips[index]['title'];
                            final message = tips[index]['message']!;

                            return OverflowBox(
                              alignment: AlignmentDirectional.topStart,
                              minHeight: 0,
                              maxHeight: double.infinity,
                              child: _MeasureSize(
                                onChange: (size) =>
                                    _onContentMeasured(index, size),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (title != null && title.isNotEmpty)
                                      Text(
                                        title,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          color: Colors.white,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    if (title != null && title.isNotEmpty)
                                      SizedBox(height: 8.h),
                                    Text(
                                      message,
                                      textAlign: TextAlign.start,
                                      maxLines: _maxMessageLines,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        color: Colors.white70,
                                        fontSize: 15.sp,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Dot indicators at top right
              PositionedDirectional(
                top: 15.h,
                end: 0,
                child: Row(
                  children: List.generate(
                    tips.length,
                    (index) => Container(
                      margin: EdgeInsetsDirectional.only(start: 4.w),
                      width: index == currentPage ? 16.w : 6.w,
                      height: 6.h,
                      decoration: BoxDecoration(
                        color: index == currentPage
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
