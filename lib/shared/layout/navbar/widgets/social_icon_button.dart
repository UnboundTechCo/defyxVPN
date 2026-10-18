import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

class SocialIconButton extends StatefulWidget {
  final String iconPath;
  final String url;
  final bool enable;
  final double? iconWidth;
  final double? iconHeight;

  const SocialIconButton({
    super.key,
    required this.iconPath,
    required this.url,
    this.enable = true,
    this.iconWidth,
    this.iconHeight,
  });

  @override
  State<SocialIconButton> createState() => _SocialIconButtonState();
}

class _SocialIconButtonState extends State<SocialIconButton> {
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

  Future<void> _handleTap() async {
    if (!widget.enable) return;
    final uri = Uri.parse(widget.url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      child: InkWell(
        hoverColor: widget.enable
            ? const Color(0xffDFDFDF)
            : Colors.transparent,
        splashColor: widget.enable
            ? const Color(0xffDFDFDF)
            : Colors.transparent,
        highlightColor: widget.enable
            ? const Color(0xffDFDFDF)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(50.r),
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 35.w,
          height: 35.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: _hasFocus && widget.enable
                ? Border.all(color: const Color(0xFFFFD700), width: 2)
                : null,
          ),
          child: Center(
            child: SvgPicture.asset(
              widget.iconPath,
              width: widget.iconWidth ?? 22.w,
              height: widget.iconHeight ?? 22.w,
              colorFilter: ColorFilter.mode(
                widget.enable ? Colors.black : const Color(0xffAEAEAE),
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
