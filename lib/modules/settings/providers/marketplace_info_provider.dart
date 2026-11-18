import 'dart:convert';

import 'package:defyx_vpn/common/dtos/subscription_usage_dto.dart';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:defyx_vpn/core/premium/api_premium.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubscriptionLinkNotFoundException implements Exception {
  const SubscriptionLinkNotFoundException();

  @override
  String toString() => 'Subscription link not found.';
}

class SubscriptionLinkResolver {
  static String? fromFlowLine(String? flowLine, String label) {
    if (flowLine == null || flowLine.isEmpty) return null;

    try {
      final methods = json.decode(flowLine);
      if (methods is! List) return null;

      final method = methods.whereType<Map>().firstWhere(
        (method) => method['label'] == label,
        orElse: () => const {},
      );
      final steps = method['steps'];
      if (steps is! List) return null;

      return steps
          .whereType<Map>()
          .map((step) => step['url'])
          .whereType<String>()
          .where(_isSubscriptionLink)
          .firstOrNull;
    } on FormatException {
      return null;
    }
  }

  static bool _isSubscriptionLink(String url) =>
      url.startsWith('https://') || url.startsWith('http://');
}

final marketplaceInfoServiceProvider = Provider<MarketplaceInfoService>(
  (ref) => MarketplaceInfoService(ref),
);

final subscriptionUsageProvider = FutureProvider.autoDispose
    .family<SubscriptionUsageResponse, String>(
      (ref, label) => ref.watch(marketplaceInfoServiceProvider).getUsage(label),
    );

class MarketplaceInfoService {
  final Ref _ref;

  MarketplaceInfoService(this._ref);

  Future<SubscriptionUsageResponse> getUsage(String label) async {
    final link = await _subscriptionLink(label);
    final premiumApi = await _ref.read(premiumApiServiceProvider.future);
    return premiumApi.getSubscriptionUsage(link);
  }

  Future<void> jumpServer(String label) async {
    final link = await _subscriptionLink(label);
    final premiumApi = await _ref.read(premiumApiServiceProvider.future);
    await premiumApi.transferServer(link);
    await _ref
        .read(flowlineServiceProvider)
        .saveFlowline(offlineMode: false, forceUpdate: true);
  }

  Future<String> _subscriptionLink(String label) async {
    final flowLine = await _ref.read(secureStorageProvider).read(flowLineKey);
    final link = SubscriptionLinkResolver.fromFlowLine(flowLine, label);
    if (link == null) throw const SubscriptionLinkNotFoundException();
    return link;
  }
}
