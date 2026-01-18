import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'speed_test_metric_item.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    
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
                  label: l10n.download,
                  value: downloadSpeed,
                  connectionStatus: connectionStatus,
                ),
              ),
            MetricItemCompact(
              label: l10n.ping,
              value: ping,
              unit: l10n.ms,
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
                  label: l10n.upload,
                  value: uploadSpeed,
                  connectionStatus: connectionStatus,
                ),
              ),
            Column(
              spacing: 5.h,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MetricItemHorizontal(
                  label: l10n.latency,
                  value: latency,
                  unit: l10n.ms,
                  connectionStatus: connectionStatus,
                ),
                MetricItemHorizontal(
                  label: l10n.packetLoss,
                  value: packetLoss,
                  unit: '%',
                  connectionStatus: connectionStatus,
                ),
                MetricItemHorizontal(
                  label: l10n.jitter,
                  value: jitter,
                  unit: l10n.ms,
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
