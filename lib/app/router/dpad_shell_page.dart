import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A [CustomTransitionPage] for pages shown inside the [ShellRoute], next to
/// the bottom navigation bar.
///
/// Every page route has its own focus scope, and by default D-pad focus stops
/// at its edges (`kDefaultRouteDirectionalTraversalEdgeBehavior` is `stop`).
/// The nav bar lives in the shell, outside the page, so a remote could never
/// reach it. This page lets directional focus continue into the shell's scope
/// ([TraversalEdgeBehavior.parentScope]) once it reaches the page's edge.
///
/// Pages covered by another page (e.g. Settings under Split Tunnel) are taken
/// out of directional traversal, so focus can't land on hidden widgets. They
/// stay focusable, so focus is restored when the covering page is popped.
class DpadShellPage<T> extends CustomTransitionPage<T> {
  const DpadShellPage({
    required super.child,
    required super.transitionsBuilder,
    super.transitionDuration,
    super.reverseTransitionDuration,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  /// Whether [context] belongs to a page shown inside the shell.
  static bool contains(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_DpadShellPageScope>() != null;

  @override
  Route<T> createRoute(BuildContext context) => _DpadShellPageRoute<T>(this);
}

class _DpadShellPageRoute<T> extends PageRoute<T> {
  _DpadShellPageRoute(DpadShellPage<T> page)
    : super(
        settings: page,
        directionalTraversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
      );

  DpadShellPage<T> get _page => settings as DpadShellPage<T>;

  @override
  bool get barrierDismissible => _page.barrierDismissible;

  @override
  Color? get barrierColor => _page.barrierColor;

  @override
  String? get barrierLabel => _page.barrierLabel;

  @override
  Duration get transitionDuration => _page.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _page.reverseTransitionDuration;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  bool get opaque => _page.opaque;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: _DpadShellPageScope(child: _page.child),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // The page's own focus scope node must never be a directional target.
    // When focus leaves the page (parentScope), Flutter also weighs this
    // node, whose rect is the whole page; from any control above the page's
    // center it would win over the nav bar and focus would just bounce back.
    // The page's contents stay traversable. (The route resets this flag when
    // it rebuilds; this callback runs right after, in the same build.)
    FocusScope.of(context, createDependency: false).skipTraversal = true;

    // This runs on every tick of this route's animation and of the route
    // pushed on top of it (the secondary animation), so it notices when the
    // page gets covered or starts leaving. `ModalRoute.isCurrentOf` can't be
    // used here: with the pages API the route is told during the build phase
    // and doesn't rebuild its scope.
    return ExcludeFocusTraversal(
      excluding: !isCurrent,
      child: _page.transitionsBuilder(
        context,
        animation,
        secondaryAnimation,
        child,
      ),
    );
  }
}

/// Marks the subtree of a [DpadShellPage].
class _DpadShellPageScope extends InheritedWidget {
  const _DpadShellPageScope({required super.child});

  @override
  bool updateShouldNotify(_DpadShellPageScope oldWidget) => false;
}
