class SettingsItem {
  final String id;
  final String title;
  final bool isEnabled;
  final bool isAccessible;
  final String? icon;
  final int? sortOrder;

  const SettingsItem({
    required this.id,
    required this.title,
    required this.isEnabled,
    required this.isAccessible,
    this.icon,
    this.sortOrder,
  });

  SettingsItem copyWith({
    String? id,
    String? title,
    bool? isEnabled,
    bool? isAccessible,
    String? icon,
    int? sortOrder,
  }) {
    return SettingsItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isEnabled: isEnabled ?? this.isEnabled,
      isAccessible: isAccessible ?? this.isAccessible,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  factory SettingsItem.fromJson(Map<String, dynamic> json) {
    return SettingsItem(
      id: json['id'] as String,
      title: json['title'] as String,
      isEnabled: json['isEnabled'] as bool,
      isAccessible: json['isAccessible'] as bool,
      icon: json['icon'] as String?,
      sortOrder: json['sortOrder'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isEnabled': isEnabled,
      'isAccessible': isAccessible,
      'icon': icon,
      'sortOrder': sortOrder,
    };
  }
}
