import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SpeedTestMetricsDisplay extends StatelessWidget {
  final double downloadSpeed;
  final double uploadSpeed;
  final int ping;
  final int latency;
  final double packetLoss;
  final int jitter;
  final bool showDownload;
  final bool showUpload;

  const SpeedTestMetricsDisplay({
    super.key,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.ping,
    required this.latency,
    required this.packetLoss,
    required this.jitter,
    required this.showDownload,
    required this.showUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          children: [
            if (showDownload)
              _MetricItem(
                label: 'DOWNLOAD',
                value: downloadSpeed.toStringAsFixed(1),
                unit: 'Mbps',
              ),
            if (showUpload)
              _MetricItem(
                label: 'UPLOAD',
                value: uploadSpeed.toStringAsFixed(1),
                unit: 'Mbps',
              ),
            if (ping > 0)
              _MetricItem(
                label: 'PING',
                value: ping.toString(),
                unit: 'ms',
              ),
          ],
        ),
        Column(
          children: [
            if (latency > 0)
              _MetricItem(
                label: 'LATENCY',
                value: latency.toString(),
                unit: 'ms',
              ),
            if (jitter > 0)
              _MetricItem(
                label: 'JITTER',
                value: jitter.toString(),
                unit: 'ms',
              ),
            if (packetLoss > 0)
              _MetricItem(
                label: 'P.LOSS',
                value: packetLoss.toStringAsFixed(1),
                unit: '%',
              ),
          ],
        ),
      ],
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _MetricItem({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              fontFamily: 'Lato',
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontFamily: 'Lato',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontFamily: 'Lato',
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
