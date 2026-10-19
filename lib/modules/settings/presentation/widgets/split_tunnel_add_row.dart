import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const Color _addIconColor = Color(0xFF7CF0A9);

class SplitTunnelAddRow extends StatefulWidget {
  final Widget typeSelector;
  final String hint;

  final Future<bool> Function(String value) onSubmit;
  final List<Widget> actions;

  const SplitTunnelAddRow({
    super.key,
    required this.typeSelector,
    required this.hint,
    required this.onSubmit,
    this.actions = const [],
  });

  @override
  State<SplitTunnelAddRow> createState() => _SplitTunnelAddRowState();
}

class _SplitTunnelAddRowState extends State<SplitTunnelAddRow> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final accepted = await widget.onSubmit(_controller.text);
    if (accepted && mounted) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: [
          widget.typeSelector,
          SizedBox(width: 12.w),
          Expanded(
            child: TextField(
              controller: _controller,
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
          ...widget.actions,
          InkWell(
            onTap: _submit,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: EdgeInsets.all(4.r),
              child: Icon(Icons.add, size: 28.sp, color: _addIconColor),
            ),
          ),
        ],
      ),
    );
  }
}
