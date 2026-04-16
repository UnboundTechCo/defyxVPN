import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/tips_widget.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';

class TipsSliderSection extends StatelessWidget {
  final ConnectionStatus status;

  const TipsSliderSection({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isDisconnected = status == ConnectionStatus.disconnected;

    return isDisconnected
        ? Column(
            children: [SizedBox(height: 170.h), const TipsSlider()],  // Much lower for smaller tips
          )
        : const SizedBox.shrink();
  }
}
