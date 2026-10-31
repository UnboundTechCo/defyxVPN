import 'package:flutter/material.dart';

class TvFocusableContainer extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final Color focusColor;
  final Color unfocusedColor;
  final double borderRadius;
  final bool enabled;
  final FocusNode? focusNode;

  const TvFocusableContainer({
    super.key,
    required this.onTap,
    required this.child,
    this.focusColor = const Color(0xFFFFD700),
    this.unfocusedColor = Colors.transparent,
    this.borderRadius = 8,
    this.enabled = true,
    this.focusNode,
  });

  @override
  State<TvFocusableContainer> createState() => _TvFocusableContainerState();
}

class _TvFocusableContainerState extends State<TvFocusableContainer> {
  late FocusNode _internalFocusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = widget.focusNode ?? FocusNode();
    _internalFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    } else {
      _internalFocusNode.removeListener(_handleFocusChange);
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _hasFocus = _internalFocusNode.hasFocus;
    });
  }

  void _triggerTap() {
    if (widget.enabled) {
      widget.onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _internalFocusNode,
      child: GestureDetector(
        onTap: widget.enabled ? _triggerTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: _hasFocus && widget.enabled
                ? Border.all(color: widget.focusColor, width: 2.0)
                : null,
            color: _hasFocus && widget.enabled
                ? widget.focusColor.withValues(alpha: 0.1)
                : widget.unfocusedColor,
          ),
          child: Opacity(
            opacity: widget.enabled ? 1.0 : 0.6,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
