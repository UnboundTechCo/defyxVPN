enum SettingsItemType {
  toggle,
  navigation,
}

class SettingsItem {
  final String id;
  final String title;
  final bool isEnabled;
  final bool isAccessible;
  final String? icon;
  final int? sortOrder;
  final String? description;
  final SettingsItemType itemType;
  final String? navigationRoute;
  final String? subtitle;
  final bool showLeftIcon;

  const SettingsItem({
    required this.id,
    required this.title,
    required this.isEnabled,
    required this.isAccessible,
    this.icon,
    this.sortOrder,
    this.description,
    this.itemType = SettingsItemType.toggle,
    this.navigationRoute,
    this.subtitle,
    this.showLeftIcon = false,
  });

  SettingsItem copyWith({
    String? id,
    String? title,
    bool? isEnabled,
    bool? isAccessible,
    String? icon,
    int? sortOrder,
    String? description,
    SettingsItemType? itemType,
    String? navigationRoute,
    String? subtitle,
    bool? showLeftIcon,
  }) {
    return SettingsItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isEnabled: isEnabled ?? this.isEnabled,
      isAccessible: isAccessible ?? this.isAccessible,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      description: description ?? this.description,
      itemType: itemType ?? this.itemType,
      navigationRoute: navigationRoute ?? this.navigationRoute,
      subtitle: subtitle ?? this.subtitle,
      showLeftIcon: showLeftIcon ?? this.showLeftIcon,
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
      description: json['description'] as String?,
      itemType: SettingsItemType.values.firstWhere(
        (e) => e.name == (json['itemType'] as String?),
        orElse: () => SettingsItemType.toggle,
      ),
      navigationRoute: json['navigationRoute'] as String?,
      subtitle: json['subtitle'] as String?,
      showLeftIcon: json['showLeftIcon'] as bool? ?? false,
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
      'description': description,
      'itemType': itemType.name,
      'navigationRoute': navigationRoute,
      'subtitle': subtitle,
      'showLeftIcon': showLeftIcon,
    };
  }
}
