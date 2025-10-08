import 'package:defyx_vpn/core/utils/format_number.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MetricItemCompact extends StatelessWidget {
  final String label;
  final num value;
  final String unit;

  const MetricItemCompact({
    super.key,
    required this.label,
    required this.value,
    this.unit = 'Mbps',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 6.h,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontFamily: 'Lato',
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
        value > 0
            ? Text(
                '${numFormatNumber(value)} $unit',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontFamily: 'Lato',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : Container(
                width: 75.w,
                height: 10.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF307065),
                  borderRadius: BorderRadius.circular(15.r),
                ),
              ),
      ],
    );
  }
}

class MetricItemHorizontal extends StatelessWidget {
  final String label;
  final num value;
  final String unit;

  const MetricItemHorizontal({
    super.key,
    required this.label,
    required this.value,
    this.unit = 'Mbps',
  });

  @override
  Widget build(BuildContext context) {
    final bool hasValue = (label == 'P.LOSS') ? true : value > 0;

    return SizedBox(
      width: 115.w,
      height: 20.h,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            top: 5.h,
            left: 0,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                fontFamily: 'Lato',
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          hasValue
              ? Positioned(
                  bottom: 0,
                  right: 0,
                  child: Text(
                    '${numFormatNumber(value)} $unit',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontFamily: 'Lato',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : Positioned(
                  bottom: 2.5.h,
                  right: 0,
                  child: Container(
                    width: 60.w,
                    height: 7.5.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF307065),
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
