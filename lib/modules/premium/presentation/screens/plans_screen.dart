import 'package:defyx_vpn/modules/premium/presentation/widgets/premium_plans_details.dart';
import 'package:defyx_vpn/modules/premium/presentation/widgets/premium_plans_options.dart';
import 'package:defyx_vpn/modules/premium/providers/selected_plan_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
    final selectedPlan = ref.watch(selectedPlanProvider);
    if (state == PlansScreenState.options) {
      return PremiumPlanSelect(navigateToDetails: _navigateToDetails);
    } else if (state == PlansScreenState.details) {
      return PremiumPlanDetails(plan: selectedPlan!);
    } else {
      return PremiumPlanSelect(navigateToDetails: _navigateToDetails);
    }
  }
}
