import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:defyx_vpn/modules/premium/presentation/widgets/premium_plans_details.dart';
import 'package:defyx_vpn/modules/premium/presentation/widgets/premium_plans_options.dart';
import 'package:defyx_vpn/modules/premium/providers/selected_plan_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum PlansScreenState { options, details }

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  PlansScreenState state = PlansScreenState.options;

  void _navigateToDetails() {
    setState(() {
      state = PlansScreenState.details;
    });
  }

  Future<void> _onPaymentSuccess() async {
    setState(() {
      state = PlansScreenState.options;
    });
    context.go(DefyxVPNRoutes.settings.route);
    await ref
        .read(flowlineServiceProvider)
        .saveFlowline(offlineMode: false, forceUpdate: true);
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlan = ref.watch(selectedPlanProvider);
    if (state == PlansScreenState.options) {
      return PremiumPlanSelect(navigateToDetails: _navigateToDetails);
    } else if (state == PlansScreenState.details) {
      return PremiumPlanDetails(
        plan: selectedPlan!,
        ref: ref,
        onPaymentSuccess: _onPaymentSuccess,
      );
    } else {
      return PremiumPlanSelect(navigateToDetails: _navigateToDetails);
    }
  }
}
