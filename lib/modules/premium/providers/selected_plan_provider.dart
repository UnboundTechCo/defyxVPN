import 'package:defyx_vpn/common/dtos/plans_dto.dart';
import 'package:defyx_vpn/core/config/api_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedPlanProvider = StateProvider<PlansResponse?>((ref) {
  return null; // Default to 6-month plan
});
final plansProvider = FutureProvider<List<PlansResponse>>((ref) async {
  final premiumService = await ref.watch(premiumApiServiceProvider.future);

  try {
    // Try to fetch fresh configs
    return await premiumService.getConfigs();
  } catch (e) {
    return [];
  }
});
