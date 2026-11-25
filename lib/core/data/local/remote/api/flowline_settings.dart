class FlowlineSettings {
  List<String> disabledAdmob;
  List<String> baseUrls;

  FlowlineSettings({required this.disabledAdmob, required this.baseUrls});

  /// Missing fields (older flowline blobs carry none) read as empty lists.
  factory FlowlineSettings.fromJson(Map<String, dynamic> json) {
    final disabledAdmob = List<String>.from(
      json["disabledAdmob"] as List? ?? const [],
    ).map((v) => v.toLowerCase()).toList();

    final baseUrls = List<String>.from(
      json["backendUrls"] as List? ?? const [],
    );
    return FlowlineSettings(disabledAdmob: disabledAdmob, baseUrls: baseUrls);
  }
}
