import 'dart:typed_data';

class InstalledApp {
  final String name;
  final String packageName;
  final Uint8List? icon;

  const InstalledApp({
    required this.name,
    required this.packageName,
    this.icon,
  });

  factory InstalledApp.fromMap(Map<dynamic, dynamic> map) {
    return InstalledApp(
      name: map['name'] as String? ?? '',
      packageName: map['packageName'] as String? ?? '',
      icon: map['icon'] as Uint8List?,
    );
  }
}
