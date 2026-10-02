import 'package:defyx_vpn/core/premium/api_premium.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final balanceProvider = FutureProvider<double>((ref) async {
  final premiumService = await ref.watch(premiumApiServiceProvider.future);
  try {
    final response = await premiumService.getBalance();
    return response.balance;
  } catch (_) {
    return 0;
  }
});
