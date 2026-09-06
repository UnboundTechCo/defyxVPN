import 'package:defyx_vpn/modules/premium/presentation/widgets/premium_wallet_topup_form.dart';
import 'package:defyx_vpn/modules/premium/presentation/widgets/premium_wallet_view.dart';
import 'package:defyx_vpn/modules/premium/providers/premium_wallet_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _showTopUpForm = false;

  @override
  Widget build(BuildContext context) {
    final premiumUser = ref.watch(balanceProvider);

    return premiumUser.when(
      data: (balance) {
        if (_showTopUpForm) {
          return PremiumTopUp(
            currentBalance: balance,
            ref: ref,
            closeTopUpForm: () => setState(() => _showTopUpForm = false),
          );
        }

        return PremiumWalletView(
          balance: balance,
          isLoading: false,
          showTopUpForm: () => setState(() => _showTopUpForm = true),
        );
      },
      loading: () => PremiumWalletView(
        balance: 0.0,
        isLoading: true,
        showTopUpForm: () => setState(() => _showTopUpForm = true),
      ),
      error: (error, stack) => Center(
        child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}
