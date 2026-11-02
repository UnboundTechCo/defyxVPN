import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SplitTunnelListCard extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Widget? footer;

  const SplitTunnelListCard({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedSliver(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
      ),
      sliver: SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
        sliver: SliverMainAxisGroup(
          slivers: [
            SliverList.builder(itemCount: itemCount, itemBuilder: itemBuilder),
            if (footer != null) SliverToBoxAdapter(child: footer),
          ],
        ),
      ),
    );
  }
}
