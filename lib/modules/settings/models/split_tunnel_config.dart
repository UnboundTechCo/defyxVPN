import 'dart:convert';

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
