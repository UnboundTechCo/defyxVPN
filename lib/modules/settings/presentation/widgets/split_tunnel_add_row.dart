import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/shared/widgets/dpad_text_field_scope.dart';
import 'package:defyx_vpn/shared/widgets/tv_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const Color _addIconColor = Color(0xFF7CF0A9);
const Color _errorColor = Color(0xFFFF6B6B);

class SplitTunnelAddRow extends StatefulWidget {
  final Widget typeSelector;
  final String hint;

  final Future<bool> Function(String value) onSubmit;
  final String? Function(String value)? validator;
  final List<Widget> actions;

  const SplitTunnelAddRow({
    super.key,
    required this.typeSelector,
    required this.hint,
    required this.onSubmit,
    this.validator,
    this.actions = const [],
  });

  @override
  State<SplitTunnelAddRow> createState() => _SplitTunnelAddRowState();
}

class _SplitTunnelAddRowState extends State<SplitTunnelAddRow> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SplitTunnelAddRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_error != null) _error = widget.validator?.call(_controller.text);
  }

  Future<void> _submit() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    final error = widget.validator?.call(text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final accepted = await widget.onSubmit(text);
    if (accepted && mounted) _controller.clear();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInputRow(),
          if (error != null)
            Padding(
              padding: EdgeInsets.only(top: 4.h, bottom: 4.h),
              child: Text(
                error,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontFamily: AppTheme.fontFamily,
                  color: _errorColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputRow() {
    return Row(
      children: [
        widget.typeSelector,
        SizedBox(width: 12.w),
        Expanded(
          // Lets remote users move past the field and shows its focus.
          child: DpadTextFieldScope(
            focusRingRadius: BorderRadius.circular(8.r),
            child: TextField(
              controller: _controller,
              onChanged: (_) => _clearError(),
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.done,
              style: TextStyle(
                fontSize: 17.sp,
                fontFamily: AppTheme.fontFamily,
                color: Colors.white,
              ),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(
                  fontSize: 17.sp,
                  fontFamily: AppTheme.fontFamily,
                  color: Colors.grey[400],
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
              ),
            ),
          ),
        ),
        ...widget.actions,
        TvFocusRing(
          shape: BoxShape.circle,
          child: InkWell(
            onTap: _submit,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: EdgeInsets.all(4.r),
              child: Icon(Icons.add, size: 28.sp, color: _addIconColor),
            ),
          ),
        ),
      ],
    );
  }
}
