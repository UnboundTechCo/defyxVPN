import 'package:defyx_vpn/core/premium/api_premium.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final balanceProvider = FutureProvider<double>((ref) async {
  if (!ref.read(authProvider.notifier).isLoggedIn) {
    return 0;
  }
  final premiumService = await ref.watch(premiumApiServiceProvider.future);
  try {
    final response = await premiumService.getBalance();
    return response.balance;
  } catch (_) {
    return 0;
  }
});
