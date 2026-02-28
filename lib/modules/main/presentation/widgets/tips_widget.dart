import 'dart:async';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/shared/providers/hints_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

final tipsCurrentPageProvider = StateProvider<int>((ref) => 0);

final tipsPageControllerProvider = Provider<PageController>((ref) {
  final controller = PageController();
  ref.onDispose(controller.dispose);
  return controller;
});

// Timer for auto-advancing tips
final tipsAutoAdvanceTimerProvider = Provider.autoDispose<Timer?>((ref) {
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

class TipsSlider extends ConsumerWidget {
  const TipsSlider({super.key});

  // Calculate dynamic height based on text content
  double _calculateHeight(String message, String? title, BuildContext context) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: message,
        style: TextStyle(
          fontFamily: 'Lato',
          color: Colors.white70,
          fontSize: 16.sp,
          height: 1.3,
        ),
      ),
      maxLines: null,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: MediaQuery.of(context).size.width - 100.w);

    // Base height for container padding and header
    double baseHeight = 100.h; // Header + padding

    // Add height for title if exists
    if (title != null && title.isNotEmpty) {
      baseHeight += 21.h; // Title height + spacing
    }

    // Add dynamic height for message
    double messageHeight = textPainter.height;

    // Ensure minimum height
    double totalHeight = baseHeight + messageHeight;
    return totalHeight < 120.h ? 120.h : totalHeight;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        
        final tips = hints.map((hint) => {
          'title': hint.title,
          'message': hint.message,
        }).toList();

        // Calculate height based on current page content
        final currentTip = tips[currentPage % tips.length];
        final dynamicHeight = _calculateHeight(
          currentTip['message']!,
          currentTip['title'],
          context,
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
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.33), width: 1),
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
                      fontFamily: 'Lato',
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
                            ref.read(tipsCurrentPageProvider.notifier).state = page;
                          },
                          itemBuilder: (context, index) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                if (tips[index]['title'] != null &&
                                    tips[index]['title']!.isNotEmpty)
                                  Text(
                                    tips[index]['title']!,
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      fontFamily: 'Lato',
                                      color: Colors.white,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                if (tips[index]['title'] != null &&
                                    tips[index]['title']!.isNotEmpty)
                                  SizedBox(height: 8.h),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Text(
                                      tips[index]['message']!,
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        fontFamily: 'Lato',
                                        color: Colors.white70,
                                        fontSize: 15.sp,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
