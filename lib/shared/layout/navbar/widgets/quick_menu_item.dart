import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QuickMenuItem extends StatefulWidget {
  final String title;
  final TextStyle? titleStyle;
  final VoidCallback onTap;
  final bool? topBorderRadius;
  final bool? bottomBorderRadius;
  final Widget? icon;
  final Widget? leadingIcon;

  const QuickMenuItem({
    super.key,
    required this.title,
    required this.onTap,
    this.topBorderRadius = false,
    this.bottomBorderRadius = false,
    this.icon,
    this.leadingIcon,
    this.titleStyle,
  });

  @override
  State<QuickMenuItem> createState() => _QuickMenuItemState();
}

class _QuickMenuItemState extends State<QuickMenuItem> {
  late FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _hasFocus = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      child: InkWell(
        onTap: widget.onTap,
        hoverColor: const Color(0xffDFDFDF),
        splashColor: const Color(0xffDFDFDF),
        highlightColor: const Color(0xffDFDFDF),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(widget.topBorderRadius! ? 12.r : 0),
          topRight: Radius.circular(widget.topBorderRadius! ? 12.r : 0),
          bottomLeft: Radius.circular(widget.bottomBorderRadius! ? 12.r : 0),
          bottomRight: Radius.circular(widget.bottomBorderRadius! ? 12.r : 0),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            border: _hasFocus
                ? Border.all(color: const Color(0xFFFFD700), width: 2)
                : null,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(widget.topBorderRadius! ? 12.r : 0),
              topRight: Radius.circular(widget.topBorderRadius! ? 12.r : 0),
              bottomLeft: Radius.circular(
                widget.bottomBorderRadius! ? 12.r : 0,
              ),
              bottomRight: Radius.circular(
                widget.bottomBorderRadius! ? 12.r : 0,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (widget.leadingIcon != null) ...[
                    widget.leadingIcon!,
                    SizedBox(width: 10.w),
                  ],
                  Text(
                    widget.title,
                    style:
                        widget.titleStyle ??
                        TextStyle(
                          fontSize: 17.sp,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
              widget.icon ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
