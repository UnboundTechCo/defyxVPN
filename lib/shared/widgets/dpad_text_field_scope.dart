import 'package:defyx_vpn/shared/tv/tv_support.dart';
import 'package:defyx_vpn/shared/utils/tv_keyboard_helper.dart';
import 'package:defyx_vpn/shared/widgets/tv_focusable.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Lets D-pad users move focus out of a single-line text field.
///
/// Flutter's text fields use Up/Down to jump the caret to the start/end and
/// Left/Right to move it, so with a TV remote focus could never leave the
/// field. Wrapping the field with this widget:
/// * moves focus with Up/Down,
/// * moves focus with Left/Right once the caret is at the start/end,
/// * reopens the on-screen keyboard with OK after Back dismissed it,
/// * optionally draws the app's focus ring (pass [focusRingRadius]) for
///   fields that have no visible border of their own.
///
/// It sits between the field and the app-wide text-editing shortcuts, so it
/// sees these keys first. It only acts on TV ([TvSupport.isTv]); elsewhere
/// the keys keep their usual text-editing meaning and no ring is drawn.
///
/// On TV it is also a focus target covering the whole field (prefix icon and
/// padding included) that passes focus on to the text inside. A text field's
/// own focus rect is just its editable area, so directional focus from a
/// control that doesn't line up with that area would otherwise skip it.
class DpadTextFieldScope extends StatefulWidget {
  const DpadTextFieldScope({
    super.key,
    required this.child,
    this.focusRingRadius,
  });

  final Widget child;

  /// Draws a focus ring with this radius around [child] while the field has
  /// D-pad/keyboard focus. No ring when null.
  final BorderRadius? focusRingRadius;

  @override
  State<DpadTextFieldScope> createState() => _DpadTextFieldScopeState();
}

class _DpadTextFieldScopeState extends State<DpadTextFieldScope> {
  final FocusNode _proxyNode = FocusNode(debugLabel: 'DpadTextFieldScope');

  @override
  void dispose() {
    _proxyNode.dispose();
    super.dispose();
  }

  /// When traversal lands on the whole-field target, focus the text inside.
  void _handleFocusChange(bool hasFocus) {
    if (!hasFocus || !_proxyNode.hasPrimaryFocus) return;
    final candidates = _proxyNode.traversalDescendants;
    final textField = candidates
        .where(
          (node) =>
              node.context?.findAncestorStateOfType<EditableTextState>() !=
              null,
        )
        .firstOrNull;
    (textField ?? candidates.firstOrNull)?.requestFocus();
  }

  static KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!TvSupport.isTv) return KeyEventResult.ignored;
    final focused = FocusManager.instance.primaryFocus;
    final editable = focused?.context
        ?.findAncestorStateOfType<EditableTextState>();
    if (focused == null || editable == null) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.select) {
      if (event is KeyDownEvent) editable.requestKeyboard();
      return KeyEventResult.handled;
    }

    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final direction = TvKeyboardHelper.directionOf(event);
    if (direction == null) return KeyEventResult.ignored;

    final value = editable.textEditingValue;
    final selection = value.selection;
    final bool canLeave;
    switch (direction) {
      case TraversalDirection.up:
      case TraversalDirection.down:
        canLeave = editable.widget.maxLines == 1;
      case TraversalDirection.left:
        canLeave =
            !selection.isValid ||
            (selection.isCollapsed && selection.baseOffset <= 0);
      case TraversalDirection.right:
        canLeave =
            !selection.isValid ||
            (selection.isCollapsed &&
                selection.baseOffset >= value.text.length);
    }
    if (!canLeave) return KeyEventResult.ignored;

    return focused.focusInDirection(direction)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isTv = TvSupport.isTv;
    final radius = isTv ? widget.focusRingRadius : null;
    return Focus(
      focusNode: _proxyNode,
      canRequestFocus: isTv,
      skipTraversal: !isTv,
      includeSemantics: false,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: radius == null
          ? widget.child
          : TvFocusRing(
              borderRadius: radius,
              fillWhenFocused: false,
              child: widget.child,
            ),
    );
  }
}
