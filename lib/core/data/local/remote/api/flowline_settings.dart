class FlowlineSettings {
  List<String> disabledAdmob;

  FlowlineSettings({required this.disabledAdmob});

  factory FlowlineSettings.fromJson(Map<String, dynamic> json) {
    List<String> disabledAdmob = List<String>.from(json["disabledAdmob"]);
    disabledAdmob = disabledAdmob.map((v) => v.toLowerCase()).toList();

    return FlowlineSettings(disabledAdmob: disabledAdmob);
  }
}
