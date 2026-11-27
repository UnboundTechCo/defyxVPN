import 'package:flutter/widgets.dart';

/// How much of the bottom of the screen floating UI (such as the nav bar)
/// covers for the widget at [context].
typedef DpadBottomObstruction = double Function(BuildContext context);

/// The app-wide focus traversal policy for D-pad and keyboard navigation.
///
/// It keeps the order of [ReadingOrderTraversalPolicy]. When traversal focuses
/// a widget that isn't fully visible — off-screen in its scrollable, or hidden
/// behind the floating nav bar — the widget is scrolled to the middle of its
/// scrollable. Widgets that are already visible cause no scrolling, so
/// non-scrolling screens stay still.
class DpadTraversalPolicy extends ReadingOrderTraversalPolicy {
  DpadTraversalPolicy({DpadBottomObstruction? bottomObstruction})
    : super(
        requestFocusCallback:
            (node, {alignmentPolicy, alignment, duration, curve}) =>
                _focusAndReveal(node, bottomObstruction),
      );

  static const Duration _revealDuration = Duration(milliseconds: 200);

  static void _focusAndReveal(
    FocusNode node,
    DpadBottomObstruction? bottomObstruction,
  ) {
    final context = node.context;
    final needsReveal =
        context != null && !_isFullyVisible(context, bottomObstruction);
    node.requestFocus();
    if (needsReveal && context.mounted) {
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: _revealDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  static bool _isFullyVisible(
    BuildContext context,
    DpadBottomObstruction? bottomObstruction,
  ) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return true;

    final target = _globalRect(context);
    var visible = _globalRect(scrollable.context);
    if (target == null || visible == null) return true;

    final media = context.getInheritedWidgetOfExactType<MediaQuery>()?.data;
    if (media != null) {
      final covered = bottomObstruction?.call(context) ?? 0;
      visible = visible.intersect(
        Rect.fromLTRB(0, 0, media.size.width, media.size.height - covered),
      );
    }

    const tolerance = 1.0;
    return target.top >= visible.top - tolerance &&
        target.bottom <= visible.bottom + tolerance &&
        target.left >= visible.left - tolerance &&
        target.right <= visible.right + tolerance;
  }

  static Rect? _globalRect(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    return MatrixUtils.transformRect(
      renderObject.getTransformTo(null),
      Offset.zero & renderObject.size,
    );
  }
}
