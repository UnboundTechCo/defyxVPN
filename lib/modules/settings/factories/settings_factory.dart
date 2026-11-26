import '../models/settings_item.dart';
import '../models/settings_group.dart';
import '../constants/settings_constants.dart';

class SettingsConfig {
  final bool showDestination;
  final bool showSplitTunnel;
  final bool showDeepScan;
  final bool showHealthCheck;
  final bool showKillSwitch;
  final List<SettingsItem> customItems;

  const SettingsConfig({
    this.showDestination = false,
    this.showSplitTunnel = true,
    this.showDeepScan = true,
    this.showHealthCheck = true,
    this.showKillSwitch = true,
    this.customItems = const [],
  });

  static const defaultConfig = SettingsConfig();
}

class SettingsFactory {
  static SettingsConfig _config = SettingsConfig.defaultConfig;

  static void configure(SettingsConfig config) {
    _config = config;
  }

  static SettingsConfig get config => _config;

  // ============== Item Factories ==============

  /// Creates a toggle item from flowline data
  static SettingsItem createFlowlineItem({
    required String label,
    required String description,
    required int sortOrder,
    bool isEnabled = false,
    bool isPremium = false,
    bool isMarket = false,
    String? id,
    String? kind,
    String? planId,
    String? planName,
    String? country,
    bool isSos = false,
    String? seller,
    List<String> features = const [],
    String? expireAt,
  }) {
    return SettingsItem(
      id: id ?? label + sortOrder.toString(),
      title: label,
      isEnabled: isEnabled,
      isAccessible: true,
      sortOrder: sortOrder,
      description: description,
      itemType: SettingsItemType.toggle,
      isPremium: isPremium,
      isMarket: isMarket,
      kind: kind,
      planId: planId,
      planName: planName,
      country: country,
      isSos: isSos,
      seller: seller,
      features: features,
      expireAt: expireAt,
    );
  }

  /// Creates a toggle item from one flowline method. [id], [sortOrder] and
  /// [isEnabled] carry the user's saved state; the rest comes from [flow].
  static SettingsItem itemFromFlow(
    Map<String, dynamic> flow, {
    required int sortOrder,
    String? id,
    bool? isEnabled,
  }) {
    String? text(String key) {
      final value = flow[key];
      if (value is String) return value.isEmpty ? null : value;
      if (value is num) return value.toString();
      return null;
    }

    return createFlowlineItem(
      id: id,
      label: text('label') ?? '',
      description: text('description') ?? '',
      sortOrder: sortOrder,
      isEnabled: isEnabled ?? flow['enabled'] == true,
      isPremium: flow['isPremium'] == true,
      isMarket: flow['isMarket'] == true,
      kind: text('kind'),
      planId: text('planId'),
      planName: text('planName'),
      country: text('country'),
      isSos: flow['sos'] == true,
      seller: text('seller'),
      features: [
        if (flow['features'] case final List<dynamic> features)
          for (final feature in features)
            if (feature is String && feature.isNotEmpty) feature,
      ],
      // The backend already sends expire_at.
      expireAt: text('expireAt') ?? text('expire_at'),
    );
  }

  /// Creates the destination navigation item
  static SettingsItem createDestinationItem({required String title}) {
    return SettingsItem(
      id: SettingsItemId.destination,
      title: title,
      isEnabled: false,
      isAccessible: true,
      sortOrder: 9999,
      itemType: SettingsItemType.navigation,
      navigationRoute: SettingsRoute.destination,
      showLeftIcon: true,
    );
  }

  /// Creates the split tunnel navigation item
  static SettingsItem createSplitTunnelItem({
    required String title,
    required String subtitle,
    bool isEnabled = false,
  }) {
    return SettingsItem(
      id: SettingsItemId.splitTunnel,
      title: title,
      isEnabled: isEnabled,
      isAccessible: true,
      sortOrder: 0,
      itemType: SettingsItemType.navigation,
      navigationRoute: SettingsRoute.splitTunnel,
      subtitle: subtitle,
    );
  }

  static SettingsItem createDeepScanItem({
    required String title,
    bool isEnabled = false,
  }) {
    return SettingsItem(
      id: SettingsItemId.deepScan,
      title: title,
      isEnabled: isEnabled,
      isAccessible: true,
      sortOrder: 0,
      itemType: SettingsItemType.toggle,
    );
  }

  static SettingsItem createHealthCheckItem({
    required String title,
    bool isEnabled = false,
  }) {
    return SettingsItem(
      id: SettingsItemId.healthCheck,
      title: title,
      isEnabled: isEnabled,
      isAccessible: true,
      sortOrder: 0,
      itemType: SettingsItemType.toggle,
    );
  }

  /// Creates the kill switch toggle item
  static SettingsItem createKillSwitchItem({
    required String title,
    bool isEnabled = false,
  }) {
    return SettingsItem(
      id: SettingsItemId.killSwitch,
      title: title,
      isEnabled: isEnabled,
      isAccessible: true,
      sortOrder: 1,
      itemType: SettingsItemType.toggle,
    );
  }

  // ============== Group Factories ==============

  /// Creates the connection method group with flowline items
  static SettingsGroup createConnectionMethodGroup({
    required String title,
    required List<SettingsItem> connectionItems,
    String? destinationTitle,
  }) {
    final List<SettingsItem> items = [...connectionItems];

    if (_config.showDestination && destinationTitle != null) {
      items.add(createDestinationItem(title: destinationTitle));
    }

    items.addAll(
      _config.customItems.where((item) => item.id.startsWith('connection_')),
    );

    return SettingsGroup(
      id: SettingsGroupId.connectionMethod,
      title: title,
      isDraggable: true,
      items: items,
    );
  }

  /// Creates the traffic control group
  static SettingsGroup createTrafficControlGroup({
    required String title,
    String? splitTunnelTitle,
    String? splitTunnelSubtitle,
    String? deepScanTitle,
    String? healthCheckTitle,
    String? killSwitchTitle,
    bool splitTunnelEnabled = false,
    bool killSwitchEnabled = false,
    bool deepScanEnabled = false,
    bool healthCheckEnabled = false,
  }) {
    final List<SettingsItem> items = [];

    if (_config.showSplitTunnel &&
        splitTunnelTitle != null &&
        splitTunnelSubtitle != null) {
      items.add(
        createSplitTunnelItem(
          title: splitTunnelTitle,
          subtitle: splitTunnelSubtitle,
          isEnabled: splitTunnelEnabled,
        ),
      );
    }

    if (_config.showDeepScan && deepScanTitle != null) {
      items.add(
        createDeepScanItem(title: deepScanTitle, isEnabled: deepScanEnabled),
      );
    }

    if (_config.showHealthCheck && healthCheckTitle != null) {
      items.add(
        createHealthCheckItem(
          title: healthCheckTitle,
          isEnabled: healthCheckEnabled,
        ),
      );
    }

    if (_config.showKillSwitch && killSwitchTitle != null) {
      items.add(
        createKillSwitchItem(
          title: killSwitchTitle,
          isEnabled: killSwitchEnabled,
        ),
      );
    }

    items.addAll(
      _config.customItems.where((item) => item.id.startsWith('traffic_')),
    );

    return SettingsGroup(
      id: SettingsGroupId.trafficControl,
      title: title,
      isDraggable: false,
      items: items,
    );
  }

  // ============== Helper Methods ==============

  /// Converts flowline data to settings items
  static List<SettingsItem> flowlineToItems(List<dynamic> flowline) {
    return flowline.asMap().entries.map((entry) {
      final flow = Map<String, dynamic>.from(entry.value as Map);
      return itemFromFlow(flow, sortOrder: entry.key);
    }).toList();
  }

  /// Gets the enabled state from saved items
  static bool getSavedItemState(List<SettingsItem>? savedItems, String itemId) {
    return savedItems?.where((i) => i.id == itemId).firstOrNull?.isEnabled ??
        false;
  }

  static SettingsItem createCustomItem({
    required String id,
    required String title,
    bool isEnabled = false,
    int sortOrder = 0,
    String? description,
    String? subtitle,
    SettingsItemType itemType = SettingsItemType.toggle,
    String? navigationRoute,
    bool showLeftIcon = false,
  }) {
    return SettingsItem(
      id: id,
      title: title,
      isEnabled: isEnabled,
      isAccessible: true,
      sortOrder: sortOrder,
      description: description,
      subtitle: subtitle,
      itemType: itemType,
      navigationRoute: navigationRoute,
      showLeftIcon: showLeftIcon,
    );
  }
}
