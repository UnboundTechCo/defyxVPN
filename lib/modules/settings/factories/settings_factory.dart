import '../models/settings_item.dart';
import '../models/settings_group.dart';
import '../constants/settings_constants.dart';

/// Factory class for creating predefined settings items and groups
class SettingsFactory {
  const SettingsFactory._();

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
      navigationRoute: SettingsRoute.splitTunnel,
      subtitle: SettingsSubtitle.splitTunnelIncluded,
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
    return SettingsGroup(
      id: SettingsGroupId.connectionMethod,
      title: SettingsGroupTitle.connectionMethod,
      isDraggable: true,
      items: [...connectionItems, createDestinationItem()],
    );
  }

  /// Creates the traffic control group
  static SettingsGroup createTrafficControlGroup({
    bool splitTunnelEnabled = false,
    bool killSwitchEnabled = false,
  }) {
    return SettingsGroup(
      id: SettingsGroupId.trafficControl,
      title: SettingsGroupTitle.trafficControl,
      isDraggable: false,
      items: [
        createSplitTunnelItem(isEnabled: splitTunnelEnabled),
        createKillSwitchItem(isEnabled: killSwitchEnabled),
      ],
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
}
