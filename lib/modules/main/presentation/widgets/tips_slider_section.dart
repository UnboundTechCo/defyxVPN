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
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 115.h),
              SizedBox(
                height: 140.h,  // Constrain TipsSlider to prevent overflow
                child: const TipsSlider(),
              ),
            ],
          )
        : const SizedBox.shrink();
  }
}
