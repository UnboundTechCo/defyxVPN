import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CopyableLink extends StatefulWidget {
  final String text;

  const CopyableLink({
    super.key,
    required this.text,
  });

  @override
  State<CopyableLink> createState() => _CopyableLinkState();
}

class _CopyableLinkState extends State<CopyableLink> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8.r),
      onTap: () async {
        await Clipboard.setData(
          ClipboardData(text: widget.text),
        );
        setState(() => _copied = true);
        Future.delayed(
          const Duration(seconds: 1),
          () => setState(() => _copied = false),
        );
      },
      child: Container(
        height: 56.h,
        padding: EdgeInsets.symmetric(vertical: 0.h, horizontal: 15.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.text,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.black,
              ),
            ),
            _copied
                ? Icon(Icons.check_circle, size: 15.w, color: Colors.green)
                : Icon(Icons.content_copy, size: 15.w, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
