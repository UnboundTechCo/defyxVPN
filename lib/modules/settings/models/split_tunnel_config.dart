import 'dart:convert';
import 'dart:io';

enum SplitTunnelMode {
  off('off'),
  excludeSelected('exclude'),
  onlySelected('only');

  final String coreValue;

  const SplitTunnelMode(this.coreValue);

  static SplitTunnelMode fromName(String? name) => SplitTunnelMode.values
      .firstWhere((m) => m.name == name, orElse: () => SplitTunnelMode.off);
}

enum SplitTunnelRuleType {
  domain,
  geoip;

  static SplitTunnelRuleType? fromName(String? name) =>
      SplitTunnelRuleType.values.where((t) => t.name == name).firstOrNull;
}

class SplitTunnelRule {
  final SplitTunnelRuleType type;
  final String value;

  const SplitTunnelRule({required this.type, required this.value});

  static const int _maxDomainLength = 253;
  static const int _maxIpv4Prefix = 32;
  static const int _maxIpv6Prefix = 128;

  static final RegExp _domainPattern = RegExp(
    r'^([a-z0-9_]([a-z0-9_-]{0,61}[a-z0-9_])?\.)+'
    r'[a-z]([a-z0-9-]{0,61}[a-z0-9])$',
  );
  static final RegExp _countryCodePattern = RegExp(r'^[a-z]{2}$');
  static final RegExp _prefixPattern = RegExp(r'^\d{1,3}$');

  static String? normalize(SplitTunnelRuleType type, String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;
    final isValid = switch (type) {
      SplitTunnelRuleType.domain => _isDomain(value),
      SplitTunnelRuleType.geoip =>
        _countryCodePattern.hasMatch(value) || _isIpRange(value),
    };
    return isValid ? value : null;
  }

  static bool _isDomain(String value) =>
      value.length <= _maxDomainLength &&
      _domainPattern.hasMatch(value) &&
      !_isIpRange(value);

  static bool _isIpRange(String value) {
    final parts = value.split('/');
    if (parts.length > 2 || parts.first.contains('%')) return false;
    final address = InternetAddress.tryParse(parts.first);
    if (address == null) return false;
    if (parts.length == 1) return true;
    if (!_prefixPattern.hasMatch(parts.last)) return false;
    final maxPrefix = address.type == InternetAddressType.IPv4
        ? _maxIpv4Prefix
        : _maxIpv6Prefix;
    return int.parse(parts.last) <= maxPrefix;
  }

  static SplitTunnelRule? parse(String raw) {
    final separator = raw.indexOf(':');
    if (separator <= 0) return null;
    final type = SplitTunnelRuleType.fromName(raw.substring(0, separator));
    final value = raw.substring(separator + 1).trim();
    if (type == null || value.isEmpty) return null;
    return SplitTunnelRule(type: type, value: value);
  }

  String get label => '${type.name}:$value';

  @override
  bool operator ==(Object other) =>
      other is SplitTunnelRule && other.type == type && other.value == value;

  @override
  int get hashCode => Object.hash(type, value);
}

class SplitTunnelConfig {
  final SplitTunnelMode mode;
  final List<SplitTunnelRule> rules;

  final List<String> apps;

  const SplitTunnelConfig({
    this.mode = SplitTunnelMode.off,
    this.rules = const [],
    this.apps = const [],
  });

  bool get isActive => mode != SplitTunnelMode.off;

  String get rulesPayload =>
      jsonEncode(rules.map((rule) => rule.label).toList());

  String rulesPayloadWith(Iterable<String> extra) =>
      jsonEncode([...rules.map((rule) => rule.label), ...extra]);

  String get appsPayload => jsonEncode(apps);

  SplitTunnelConfig copyWith({
    SplitTunnelMode? mode,
    List<SplitTunnelRule>? rules,
    List<String>? apps,
  }) {
    return SplitTunnelConfig(
      mode: mode ?? this.mode,
      rules: rules ?? this.rules,
      apps: apps ?? this.apps,
    );
  }

  factory SplitTunnelConfig.fromJson(Map<String, dynamic> json) {
    return SplitTunnelConfig(
      mode: SplitTunnelMode.fromName(json['mode'] as String?),
      rules: (json['rules'] as List<dynamic>? ?? const [])
          .map((raw) => SplitTunnelRule.parse(raw as String))
          .whereType<SplitTunnelRule>()
          .toList(),
      apps: (json['apps'] as List<dynamic>? ?? const [])
          .map((app) => app as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'rules': rules.map((rule) => rule.label).toList(),
    'apps': apps,
  };
}
