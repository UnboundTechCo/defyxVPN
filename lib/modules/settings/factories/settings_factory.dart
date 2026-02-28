import '../models/settings_item.dart';
import '../models/settings_group.dart';
import '../constants/settings_constants.dart';

class SettingsConfig {
  final bool showDestination;
  final bool showSplitTunnel;
  final bool showDeepScan;
  final bool showKillSwitch;
  final List<SettingsItem> customItems;

  const SettingsConfig({
    this.showDestination = false,
    this.showSplitTunnel = false,
    this.showKillSwitch = false,
    this.showDeepScan = true,
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
  }) {
    return SettingsItem(
      id: label,
      title: label,
      isEnabled: isEnabled,
      isAccessible: true,
      sortOrder: sortOrder,
      description: description,
      itemType: SettingsItemType.toggle,
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

    items.addAll(_config.customItems.where(
      (item) => item.id.startsWith('connection_'),
    ));

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
    String? killSwitchTitle,
    bool splitTunnelEnabled = false,
    bool killSwitchEnabled = false,
    bool deepScanEnabled = false,
  }) {
    final List<SettingsItem> items = [];

    if (_config.showSplitTunnel && splitTunnelTitle != null && splitTunnelSubtitle != null) {
      items.add(createSplitTunnelItem(
        title: splitTunnelTitle,
        subtitle: splitTunnelSubtitle,
        isEnabled: splitTunnelEnabled,
      ));
    }

    if (_config.showDeepScan && deepScanTitle != null) {
      items.add(createDeepScanItem(
        title: deepScanTitle,
        isEnabled: deepScanEnabled,
      ));
    }

    if (_config.showKillSwitch && killSwitchTitle != null) {
      items.add(createKillSwitchItem(
        title: killSwitchTitle,
        isEnabled: killSwitchEnabled,
      ));
    }

    items.addAll(_config.customItems.where(
      (item) => item.id.startsWith('traffic_'),
    ));

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
      final flow = entry.value as Map<String, dynamic>;
      return createFlowlineItem(
        label: flow['label'] ?? '',
        description: flow['description'] ?? '',
        sortOrder: entry.key,
        isEnabled: flow['enabled'] ?? false,
      );
    }).toList();
  }

  /// Gets the enabled state from saved items
  static bool getSavedItemState(
    List<SettingsItem>? savedItems,
    String itemId,
  ) {
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
