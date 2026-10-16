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

final tipsCurrentPageProvider = StateProvider<int>((ref) => 0);

final tipsPageControllerProvider = Provider<PageController>((ref) {
  final controller = PageController();
  ref.onDispose(controller.dispose);
  return controller;
});

// Timer for auto-advancing tips
final tipsAutoAdvanceTimerProvider = Provider<Timer?>((ref) {
  final pageController = ref.watch(tipsPageControllerProvider);
  final tipsAsync = ref.watch(selectedHintsProvider);

  return tipsAsync.when(
    data: (hints) {
      if (hints.isEmpty) return null;

      final timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (pageController.hasClients) {
          final currentPage = ref.read(tipsCurrentPageProvider);
          final nextPage = (currentPage + 1) % hints.length;
          ref.read(tipsCurrentPageProvider.notifier).state = nextPage;
          pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });

      ref.onDispose(timer.cancel);
      return timer;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

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

  final Map<int, double> _measuredContentHeights = {};

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
    final pageController = ref.watch(tipsPageControllerProvider);
    final tipsAsync = ref.watch(selectedHintsProvider);
    final currentPage = ref.watch(tipsCurrentPageProvider);
    final l10n = AppLocalizations.of(context);

    // Start auto-advance timer
    ref.watch(tipsAutoAdvanceTimerProvider);

    return tipsAsync.when(
      data: (hints) {
        if (hints.isEmpty) {
          return const SizedBox.shrink();
        }

        final tips = hints
            .map((hint) => {'title': hint.title, 'message': hint.message})
            .toList();

        final pageIndex = currentPage % tips.length;
        final measuredContentHeight = _measuredContentHeights[pageIndex];
        final dynamicHeight = measuredContentHeight == null
            ? _minHeight.h
            : (measuredContentHeight + _structuralOverhead.h).clamp(
                _minHeight.h,
                double.infinity,
              );

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
              width: 1,
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
                          controller: pageController,
                          itemCount: tips.length,
                          onPageChanged: (page) {
                            ref.read(tipsCurrentPageProvider.notifier).state =
                                page;
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
