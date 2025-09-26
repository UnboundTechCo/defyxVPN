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

    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        offset: isDisconnected ? Offset.zero : const Offset(0.0, 0.3),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          opacity: isDisconnected ? 1.0 : 0.0,
          child: isDisconnected
              ? Column(
                  children: [SizedBox(height: 0.05.sh), const TipsSlider()],
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
