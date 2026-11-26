enum SettingsItemType { toggle, navigation }

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
  final bool isPremium;
  final bool isMarket;

  // Where a connection method comes from, as the flowline describes it. All
  // optional: older flowlines only send isPremium/isMarket.

  /// premium, market, builtin, or a reward type (invite, trial, queue, gift…).
  final String? kind;

  /// The subscription this method belongs to; a plan's locations share it.
  final String? planId;
  final String? planName;

  /// The location's country code, for a plan with several locations.
  final String? country;

  /// The plan's "any location" method (all of its locations together).
  final bool isSos;

  /// Who sells a market config.
  final String? seller;

  /// What a premium plan offers, shown next to its name.
  final List<String> features;

  /// When the method stops working, as an ISO 8601 date.
  final String? expireAt;

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
    this.isPremium = false,
    this.isMarket = false,
    this.kind,
    this.planId,
    this.planName,
    this.country,
    this.isSos = false,
    this.seller,
    this.features = const [],
    this.expireAt,
  });

  DateTime? get expiresAt =>
      expireAt == null ? null : DateTime.tryParse(expireAt!)?.toLocal();

  bool isExpiredAt(DateTime now) {
    final ends = expiresAt;
    return ends != null && !ends.isAfter(now);
  }

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
    bool? isPremium,
    bool? isMarket,
    String? kind,
    String? planId,
    String? planName,
    String? country,
    bool? isSos,
    String? seller,
    List<String>? features,
    String? expireAt,
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
      isPremium: isPremium ?? this.isPremium,
      isMarket: isMarket ?? this.isMarket,
      kind: kind ?? this.kind,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      country: country ?? this.country,
      isSos: isSos ?? this.isSos,
      seller: seller ?? this.seller,
      features: features ?? this.features,
      expireAt: expireAt ?? this.expireAt,
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
      isPremium: json['isPremium'] as bool? ?? false,
      isMarket: json['isMarket'] as bool? ?? false,
      kind: json['kind'] as String?,
      planId: json['planId'] as String?,
      planName: json['planName'] as String?,
      country: json['country'] as String?,
      isSos: json['isSos'] as bool? ?? false,
      seller: json['seller'] as String?,
      features: [
        for (final feature in json['features'] as List<dynamic>? ?? const [])
          if (feature is String) feature,
      ],
      expireAt: json['expireAt'] as String?,
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
      'isPremium': isPremium,
      'isMarket': isMarket,
      'kind': kind,
      'planId': planId,
      'planName': planName,
      'country': country,
      'isSos': isSos,
      'seller': seller,
      'features': features,
      'expireAt': expireAt,
    };
  }
}
