class FlowlineSettings {
  List<String> disabledAdmob;
  List<String> baseUrls;

  FlowlineSettings({required this.disabledAdmob, required this.baseUrls});

  factory FlowlineSettings.fromJson(Map<String, dynamic> json) {
    List<String> disabledAdmob = List<String>.from(json["disabledAdmob"]);
    disabledAdmob = disabledAdmob.map((v) => v.toLowerCase()).toList();

    List<String> baseUrls = List<String>.from(json["backendUrls"]);
    return FlowlineSettings(disabledAdmob: disabledAdmob, baseUrls: baseUrls);
  }
}
