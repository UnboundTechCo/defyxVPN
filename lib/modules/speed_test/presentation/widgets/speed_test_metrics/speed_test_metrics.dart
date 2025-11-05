import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'speed_test_metric_item.dart';

class SpeedTestMetricsDisplay extends StatelessWidget {
  final double downloadSpeed;
  final double uploadSpeed;
  final int ping;
  final int latency;
  final double packetLoss;
  final int jitter;
  final bool showDownload;
  final bool showUpload;
  final ConnectionStatus connectionStatus;

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
    required this.connectionStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          spacing: 5.h,
          children: [
            if (showDownload)
              SizedBox(
                height: 65.h,
                child: MetricItemCompact(
                  label: 'DOWNLOAD',
                  value: downloadSpeed,
                  connectionStatus: connectionStatus,
                ),
              ),
            MetricItemCompact(
              label: 'PING',
              value: ping,
              unit: 'ms',
              connectionStatus: connectionStatus,
            ),
          ],
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 5.h,
          children: [
            if (showUpload)
              SizedBox(
                height: 65.h,
                child: MetricItemCompact(
                  label: 'UPLOAD',
                  value: uploadSpeed,
                  connectionStatus: connectionStatus,
                ),
              ),
            Column(
              spacing: 5.h,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MetricItemHorizontal(
                  label: 'LATENCY',
                  value: latency,
                  unit: 'ms',
                  connectionStatus: connectionStatus,
                ),
                MetricItemHorizontal(
                  label: 'P.LOSS',
                  value: packetLoss,
                  unit: '%',
                  connectionStatus: connectionStatus,
                ),
                MetricItemHorizontal(
                  label: 'JITTER',
                  value: jitter,
                  unit: 'ms',
                  connectionStatus: connectionStatus,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
