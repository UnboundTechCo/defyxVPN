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
  static SettingsItem createDestinationItem() {
    return const SettingsItem(
      id: SettingsItemId.destination,
      title: SettingsItemTitle.destination,
      isEnabled: false,
      isAccessible: true,
      sortOrder: 9999,
      itemType: SettingsItemType.navigation,
      navigationRoute: SettingsRoute.destination,
      showLeftIcon: true,
    );
  }

  /// Creates the split tunnel navigation item
  static SettingsItem createSplitTunnelItem({bool isEnabled = false}) {
    return SettingsItem(
      id: SettingsItemId.splitTunnel,
      title: SettingsItemTitle.splitTunnel,
      isEnabled: isEnabled,
      isAccessible: true,
      sortOrder: 0,
      itemType: SettingsItemType.navigation,
      subtitle: SettingsSubtitle.splitTunnelIncluded,
    );
  }

  static SettingsItem createDeepScanItem({bool isEnabled = false}) {
    return SettingsItem(
      id: SettingsItemId.deepScan,
      title: SettingsItemTitle.deepScan,
      isEnabled: isEnabled,
      isAccessible: true,
      sortOrder: 0,
      itemType: SettingsItemType.toggle,
  
    );
  }

  /// Creates the kill switch toggle item
  static SettingsItem createKillSwitchItem({bool isEnabled = false}) {
    return SettingsItem(
      id: SettingsItemId.killSwitch,
      title: SettingsItemTitle.killSwitch,
      isEnabled: isEnabled,
      isAccessible: true,
      sortOrder: 1,
      itemType: SettingsItemType.toggle,
    );
  }

  // ============== Group Factories ==============

  /// Creates the connection method group with flowline items
  static SettingsGroup createConnectionMethodGroup({
    required List<SettingsItem> connectionItems,
  }) {
    final List<SettingsItem> items = [...connectionItems];

    if (_config.showDestination) {
      items.add(createDestinationItem());
    }

    items.addAll(_config.customItems.where(
      (item) => item.id.startsWith('connection_'),
    ));

    return SettingsGroup(
      id: SettingsGroupId.connectionMethod,
      title: SettingsGroupTitle.connectionMethod,
      isDraggable: true,
      items: items,
    );
  }

  /// Creates the traffic control group
  static SettingsGroup createTrafficControlGroup({
    bool splitTunnelEnabled = false,
    bool killSwitchEnabled = false,
    bool deepScanEnabled = false,
  }) {
    final List<SettingsItem> items = [];

    if (_config.showSplitTunnel) {
      items.add(createSplitTunnelItem(isEnabled: splitTunnelEnabled));
    }

    if (_config.showDeepScan) {
      items.add(createDeepScanItem(isEnabled: deepScanEnabled));
    }

    if (_config.showKillSwitch) {
      items.add(createKillSwitchItem(isEnabled: killSwitchEnabled));
    }

    items.addAll(_config.customItems.where(
      (item) => item.id.startsWith('traffic_'),
    ));

    return SettingsGroup(
      id: SettingsGroupId.trafficControl,
      title: SettingsGroupTitle.trafficControl,
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
