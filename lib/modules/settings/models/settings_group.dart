import 'settings_item.dart';

class SettingsGroup {
  final String id;
  final String title;
  final List<SettingsItem> items;
  final bool isDraggable;

  /// Plans the user switched off. Their locations keep their own switches, so
  /// switching the plan back on restores them.
  final List<String> disabledPlans;

  /// Sections and plans the user opened or closed, by their layout key.
  /// Ones not listed use their default.
  final Map<String, bool> expanded;

  SettingsGroup({
    required this.id,
    required this.title,
    required this.items,
    required this.isDraggable,
    this.disabledPlans = const [],
    this.expanded = const {},
  });

  SettingsGroup copyWith({
    String? id,
    String? title,
    List<SettingsItem>? items,
    bool? isDraggable,
    List<String>? disabledPlans,
    Map<String, bool>? expanded,
  }) {
    return SettingsGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      items: items ?? this.items,
      isDraggable: isDraggable ?? this.isDraggable,
      disabledPlans: disabledPlans ?? this.disabledPlans,
      expanded: expanded ?? this.expanded,
    );
  }

  factory SettingsGroup.fromJson(Map<String, dynamic> json) {
    final expanded = json['expanded'];
    return SettingsGroup(
      id: json['id'] as String,
      title: json['title'] as String,
      items: (json['items'] as List<dynamic>)
          .map((item) => SettingsItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      isDraggable: json['isDraggable'] as bool,
      disabledPlans: [
        for (final plan in json['disabledPlans'] as List<dynamic>? ?? const [])
          if (plan is String) plan,
      ],
      expanded: {
        if (expanded is Map)
          for (final entry in expanded.entries)
            if (entry.key is String && entry.value is bool)
              entry.key as String: entry.value as bool,
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'items': items.map((item) => item.toJson()).toList(),
      'isDraggable': isDraggable,
      'disabledPlans': disabledPlans,
      'expanded': expanded,
    };
  }
}
