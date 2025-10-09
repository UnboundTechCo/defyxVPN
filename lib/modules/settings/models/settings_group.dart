import 'settings_item.dart';

class SettingsGroup {
  final String id;
  final String title;
  final List<SettingsItem> items;
  final bool isDraggable;

  SettingsGroup({
    required this.id,
    required this.title,
    required this.items,
    required this.isDraggable,
  });

  SettingsGroup copyWith({
    String? id,
    String? title,
    List<SettingsItem>? items,
    bool? isDraggable,
  }) {
    return SettingsGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      items: items ?? this.items,
      isDraggable: isDraggable ?? this.isDraggable,
    );
  }

  factory SettingsGroup.fromJson(Map<String, dynamic> json) {
    return SettingsGroup(
      id: json['id'] as String,
      title: json['title'] as String,
      items: (json['items'] as List<dynamic>)
          .map((item) => SettingsItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      isDraggable: json['isDraggable'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'items': items.map((item) => item.toJson()).toList(),
      'isDraggable': isDraggable,
    };
  }
}
