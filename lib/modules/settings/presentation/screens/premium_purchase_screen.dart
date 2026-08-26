import 'dart:io';

import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_premium_login_dialog.dart';
import 'package:defyx_vpn/modules/settings/providers/premium_purchase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PremiumPurchaseScreen extends ConsumerWidget {
  const PremiumPurchaseScreen({super.key});

  static Future<void> show(BuildContext context, WidgetRef ref) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PremiumPurchaseScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final purchaseState = ref.watch(premiumPurchaseProvider);
    final notifier = ref.read(premiumPurchaseProvider.notifier);

    if (!Platform.isIOS) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.settingsMarketplace)),
        body: const SizedBox.shrink(),
      );
    }

    ref.listen(premiumPurchaseProvider, (previous, next) {
      final purchase = next.lastPurchase;
      if (purchase == null || purchase == previous?.lastPurchase) return;

      final message = switch (purchase.status) {
        PurchaseStatus.pending => 'Purchase pending',
        PurchaseStatus.error => purchase.error?.message ?? 'Purchase failed',
        PurchaseStatus.canceled => 'Purchase canceled',
        PurchaseStatus.purchased ||
        PurchaseStatus.restored => 'Purchase received and awaiting activation',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsMarketplace)),
      body: RefreshIndicator(
        onRefresh: notifier.loadProducts,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Defyx Premium',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a Premium subscription to unlock the Defyx VPN service. '
              'Subscriptions renew automatically until canceled.',
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => SettingsPremiumLoginDialog.show(context, ref),
              icon: const Icon(Icons.login),
              label: const Text('Load existing Premium configuration'),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            if (purchaseState.isLoading && purchaseState.products.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (!purchaseState.isAvailable)
              const Text('In-App Purchase is currently unavailable.')
            else if (purchaseState.products.isEmpty)
              const Text('Premium plans are currently unavailable.')
            else
              ...purchaseState.products.map(
                (product) => Card(
                  child: ListTile(
                    title: Text(product.title),
                    subtitle: Text(product.description),
                    trailing: Text(product.price),
                    onTap: purchaseState.isLoading
                        ? null
                        : () => notifier.purchase(product),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: purchaseState.isLoading
                  ? null
                  : notifier.restorePurchases,
              child: const Text('Restore Purchases'),
            ),
            if (purchaseState.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                purchaseState.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
