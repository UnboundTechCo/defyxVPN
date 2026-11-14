import 'package:defyx_vpn/core/theme/app_colors.dart';
import 'package:defyx_vpn/modules/speed_test/application/speed_test_provider.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_progress/speed_gauge_scale.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_progress/speed_test_progress_indicator.dart';
import 'package:defyx_vpn/modules/speed_test/models/speed_test_result.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';

class SpeedTestUploadState extends ConsumerWidget {
  final SpeedTestState state;
  final VoidCallback onStop;

  const SpeedTestUploadState({
    super.key,
    required this.state,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionStateProvider);
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SpeedTestProgressIndicator(
            progress: SpeedGaugeScale.fractionFor(state.currentSpeed),
            color: AppColors.uploadColor,
            showButton: false,
            centerValue: state.currentSpeed,
            centerUnit: l10n.mbps,
            subtitle: l10n.upload,
            result: state.result,
            currentStep: SpeedTestStep.upload,
            connectionStatus: connectionState.status,
            onStop: onStop,
          ),
        ),
      ],
    );
  }
}
