// Group IDs
abstract class SettingsGroupId {
  static const connectionMethod = 'connection_method';
  static const trafficControl = 'traffic_control';
}

// Group Titles
abstract class SettingsGroupTitle {
  static const connectionMethod = 'CONNECTION METHOD';
  static const trafficControl = 'TRAFFIC CONTROL';
}

// Item IDs
abstract class SettingsItemId {
  static const destination = 'destination';
  static const splitTunnel = 'split_tunnel';
  static const killSwitch = 'kill_switch';
}

// Item Titles
abstract class SettingsItemTitle {
  static const destination = 'DESTINATION';
  static const splitTunnel = 'SPLIT TUNNEL';
  static const killSwitch = 'KILL SWITCH';
}

// Navigation Routes
abstract class SettingsRoute {
  static const destination = '/settings/destination';
  static const splitTunnel = '/settings/split_tunnel';
}

// Subtitles
abstract class SettingsSubtitle {
  static const splitTunnelIncluded = 'INCLUDED';
}

// Messages
abstract class SettingsMessage {
  static const atLeastOneCoreRequired = 'At least one core must remain enabled';
}

// Storage Keys
abstract class SettingsStorageKey {
  static const appSettings = 'app_settings_v2';
}
