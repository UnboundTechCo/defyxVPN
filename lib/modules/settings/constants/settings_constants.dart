// Group IDs
abstract class SettingsGroupId {
  static const connectionMethod = 'connection_method';
  static const trafficControl = 'traffic_control';
}

// Item IDs
abstract class SettingsItemId {
  static const destination = 'destination';
  static const splitTunnel = 'split_tunnel';
  static const killSwitch = 'kill_switch';
  static const deepScan = 'deep_scan';
}

// Navigation Routes
abstract class SettingsRoute {
  static const destination = '/settings/destination';
  static const splitTunnel = '/settings/split_tunnel';
}

// Storage Keys
abstract class SettingsStorageKey {
  static const appSettings = 'app_settings_v2';
}
