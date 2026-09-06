import 'package:defyx_vpn/core/config/api_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final balanceProvider = FutureProvider<double>((ref) async {
  final premiumService = await ref.watch(premiumApiServiceProvider.future);
  try {
    final response = await premiumService.getBalance();
    return response.balance;
  } catch (e) {
    return 0;
  }
});
