import 'dart:async';

import 'package:defyx_vpn/shared/utils/tv_keyboard_helper.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A control that works with a TV remote (D-pad), a keyboard and touch.
///
/// * It is a single focus stop. OK (D-pad center), Enter, Space and gamepad A
///   call [onTap] on key down. Key repeats and key up are swallowed, so
///   holding OK can't fire the action over and over.
/// * With [onSelectLongPress], holding OK calls it instead (on the first key
///   repeat, or after [kLongPressTimeout]), and a short press calls [onTap]
///   when the key is released.
/// * [onKeyEvent] runs before the built-in handling (e.g. for a move mode).
/// * A gold focus ring is drawn only while focused *and* the focus highlight
///   mode is traditional (remote/keyboard), so touch users never see it.
/// * Touch goes through a [GestureDetector]. Set [handleTaps] to false when
///   the child already handles taps itself (e.g. an [InkWell] for its ripple);
///   such a child should not take focus (`canRequestFocus: false`).
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.onSelectLongPress,
    this.onKeyEvent,
    this.onFocusChange,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.handleTaps = true,
    this.behavior = HitTestBehavior.opaque,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
    this.ringColor = focusRingColor,
    this.ringWidth = 2,
    this.ringOutset = 0,
    this.fillWhenFocused = true,
  });

  /// The app-wide focus indicator color.
  static const Color focusRingColor = Color(0xFFFFD700);

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onSelectLongPress;
  final FocusOnKeyEventCallback? onKeyEvent;
  final ValueChanged<bool>? onFocusChange;
  final FocusNode? focusNode;
  final bool autofocus;

  /// When false the control can't take focus and ignores taps and keys.
  final bool enabled;
  final bool handleTaps;
  final HitTestBehavior behavior;
  final BoxShape shape;

  /// Corner radius of the ring for [BoxShape.rectangle].
  final BorderRadius? borderRadius;
  final Color ringColor;
  final double ringWidth;

  /// Draws the ring this far outside the child's bounds without affecting
  /// layout.
  final double ringOutset;

  /// Adds a light tint inside the ring.
  final bool fillWhenFocused;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _focused = false;
  late FocusHighlightMode _highlightMode;
  Timer? _longPressTimer;
  bool _selectDown = false;
  bool _longPressFired = false;

  @override
  void initState() {
    super.initState();
    // A rebuilt widget can re-attach a node that is already focused (e.g. a
    // list row moved to a new index), so start from the node's real state.
    _focused = widget.focusNode?.hasFocus ?? false;
    _highlightMode = FocusManager.instance.highlightMode;
    FocusManager.instance.addHighlightModeListener(_handleHighlightModeChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(
      _handleHighlightModeChange,
    );
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _handleHighlightModeChange(FocusHighlightMode mode) {
    if (!mounted || mode == _highlightMode) return;
    setState(() => _highlightMode = mode);
  }

  void _handleFocusChange(bool focused) {
    if (!focused) _resetLongPress();
    if (mounted) setState(() => _focused = focused);
    widget.onFocusChange?.call(focused);
  }

  void _resetLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _selectDown = false;
    _longPressFired = false;
  }

  void _fireLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    if (!mounted || _longPressFired) return;
    _longPressFired = true;
    widget.onSelectLongPress?.call();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final hook = widget.onKeyEvent;
    if (hook != null) {
      final result = hook(node, event);
      if (result != KeyEventResult.ignored) return result;
    }

    if (!widget.enabled ||
        (widget.onTap == null && widget.onSelectLongPress == null) ||
        !TvKeyboardHelper.isActivationKey(event)) {
      return KeyEventResult.ignored;
    }

    if (widget.onSelectLongPress == null) {
      if (event is KeyDownEvent) widget.onTap?.call();
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent) {
      _resetLongPress();
      _selectDown = true;
      // Fallback for keys that don't auto-repeat while held.
      _longPressTimer = Timer(kLongPressTimeout, _fireLongPress);
    } else if (event is KeyRepeatEvent) {
      // Android starts repeating a held key after its long-press timeout
      // (the first repeat carries FLAG_LONG_PRESS), so that is the signal.
      if (_selectDown && !_longPressFired) _fireLongPress();
    } else if (event is KeyUpEvent) {
      final isShortPress = _selectDown && !_longPressFired;
      _resetLongPress();
      if (isShortPress) widget.onTap?.call();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final showRing =
        _focused &&
        widget.enabled &&
        _highlightMode == FocusHighlightMode.traditional;

    Widget result = _FocusRingOverlay(
      visible: showRing,
      shape: widget.shape,
      borderRadius: widget.borderRadius,
      color: widget.ringColor,
      width: widget.ringWidth,
      outset: widget.ringOutset,
      fill: widget.fillWhenFocused,
      child: widget.child,
    );

    if (widget.handleTaps) {
      result = GestureDetector(
        behavior: widget.behavior,
        onTap: widget.enabled ? widget.onTap : null,
        child: result,
      );
    }

    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: widget.enabled,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        cursor: widget.enabled && widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        child: result,
      ),
    );
  }
}

/// Draws the app's focus ring around [child] while a focusable widget inside
/// it (an [InkWell], [IconButton], [PopupMenuButton], …) has remote/keyboard
/// focus.
///
/// Material controls show focus as ink, which is painted on the nearest
/// [Material] underneath the content. The app's dark screens paint their
/// background above the Scaffold's Material, so that ink is never visible;
/// this ring is drawn on top instead. The child keeps handling focus and keys.
class TvFocusRing extends StatefulWidget {
  const TvFocusRing({
    super.key,
    required this.child,
    this.enabled = true,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
    this.ringOutset = 0,
    this.fillWhenFocused = true,
  });

  final Widget child;

  /// When false no ring is drawn, e.g. while the wrapped control is inactive
  /// but contains another focusable control with its own ring.
  final bool enabled;
  final BoxShape shape;
  final BorderRadius? borderRadius;
  final double ringOutset;
  final bool fillWhenFocused;

  @override
  State<TvFocusRing> createState() => _TvFocusRingState();
}

class _TvFocusRingState extends State<TvFocusRing> {
  bool _hasFocus = false;
  late FocusHighlightMode _highlightMode;

  @override
  void initState() {
    super.initState();
    _highlightMode = FocusManager.instance.highlightMode;
    FocusManager.instance.addHighlightModeListener(_handleHighlightModeChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(
      _handleHighlightModeChange,
    );
    super.dispose();
  }

  void _handleHighlightModeChange(FocusHighlightMode mode) {
    if (!mounted || mode == _highlightMode) return;
    setState(() => _highlightMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (hasFocus) {
        if (mounted && hasFocus != _hasFocus) {
          setState(() => _hasFocus = hasFocus);
        }
      },
      child: _FocusRingOverlay(
        visible:
            widget.enabled &&
            _hasFocus &&
            _highlightMode == FocusHighlightMode.traditional,
        shape: widget.shape,
        borderRadius: widget.borderRadius,
        color: TvFocusable.focusRingColor,
        width: 2,
        outset: widget.ringOutset,
        fill: widget.fillWhenFocused,
        child: widget.child,
      ),
    );
  }
}

/// The ring itself: drawn over [child] (outside its bounds by [outset])
/// without affecting layout or hit testing.
class _FocusRingOverlay extends StatelessWidget {
  const _FocusRingOverlay({
    required this.visible,
    required this.shape,
    required this.borderRadius,
    required this.color,
    required this.width,
    required this.outset,
    required this.fill,
    required this.child,
  });

  final bool visible;
  final BoxShape shape;
  final BorderRadius? borderRadius;
  final Color color;
  final double width;
  final double outset;
  final bool fill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ringRadius = shape == BoxShape.circle || borderRadius == null
        ? null
        : borderRadius! + BorderRadius.circular(outset);

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned(
          left: -outset,
          top: -outset,
          right: -outset,
          bottom: -outset,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: shape,
                  borderRadius: ringRadius,
                  color: fill ? color.withValues(alpha: 0.12) : null,
                  border: Border.all(color: color, width: width),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
