import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SplitTunnelListCard extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Widget? footer;
  final double? maxHeight;

  const SplitTunnelListCard({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.footer,
    this.maxHeight,
  });

  @override
  State<SplitTunnelListCard> createState() => _SplitTunnelListCardState();
}

class _SplitTunnelListCardState extends State<SplitTunnelListCard> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  BoxDecoration get _decoration => BoxDecoration(
    color: Colors.white.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(16.r),
  );

  EdgeInsets get _padding =>
      EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h);

  @override
  Widget build(BuildContext context) {
    final maxHeight = widget.maxHeight;
    final footer = widget.footer;

    if (maxHeight == null) {
      return DecoratedSliver(
        decoration: _decoration,
        sliver: SliverPadding(
          padding: _padding,
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverList.builder(
                itemCount: widget.itemCount,
                itemBuilder: widget.itemBuilder,
              ),
              if (footer != null) SliverToBoxAdapter(child: footer),
            ],
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Container(
        decoration: _decoration,
        clipBehavior: Clip.antiAlias,
        padding: _padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Scrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const ClampingScrollPhysics(),
                  itemCount: widget.itemCount,
                  itemBuilder: widget.itemBuilder,
                ),
              ),
            ),
            ?footer,
          ],
        ),
      ),
    );
  }
}
