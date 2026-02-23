import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

// Group IDs
abstract class SettingsGroupId {
  static const connectionMethod = 'connection_method';
  static const trafficControl = 'traffic_control';
}

// Group Titles
abstract class SettingsGroupTitle {
  static const connectionMethod = 'CONNECTION METHOD';
  static const trafficControl = 'ESCAPE MODE';
}

// Item IDs
abstract class SettingsItemId {
  static const destination = 'destination';
  static const splitTunnel = 'split_tunnel';
  static const killSwitch = 'kill_switch';
  static const deepScan = 'deep_scan';
}

// Item Titles
abstract class SettingsItemTitle {
  static const destination = 'DESTINATION';
  static const splitTunnel = 'SPLIT TUNNEL';
  static const killSwitch = 'KILL SWITCH';
  static const deepScan = 'DEEP SCAN';
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

// Localized text helper - fetches translations with fallback to defaults
class SettingsText {
  final BuildContext? context;
  
  SettingsText([this.context]);
  
  AppLocalizations? get _l10n => context != null ? AppLocalizations.of(context!) : null;
  
  String get escapeModeTitle => _l10n?.settingsEscapeMode ?? SettingsGroupTitle.trafficControl;
  String get splitTunnelTitle => _l10n?.settingsSplitTunnel ?? SettingsItemTitle.splitTunnel;
  String get splitTunnelSubtitle => _l10n?.settingsIncluded ?? SettingsSubtitle.splitTunnelIncluded;
  String get deepScanTitle => _l10n?.settingsDeepScan ?? SettingsItemTitle.deepScan;
  String get killSwitchTitle => _l10n?.settingsKillSwitch ?? SettingsItemTitle.killSwitch;
  String get connectionMethodTitle => _l10n?.settingsConnectionMethod ?? SettingsGroupTitle.connectionMethod;
  String get destinationTitle => _l10n?.settingsDestination ?? SettingsItemTitle.destination;
  String get atLeastOneCoreRequired => _l10n?.settingsAtLeastOneCoreRequired ?? SettingsMessage.atLeastOneCoreRequired;
}
