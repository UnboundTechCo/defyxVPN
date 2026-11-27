import 'package:version/version.dart';

/// Parses an app version string such as "5.13.3" or "5.13.3+316", ignoring
/// the "+build" part the same way the update check does. Returns null when
/// the string is missing or can't be parsed.
Version? parseAppVersion(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  try {
    return Version.parse(raw.split('+').first);
  } catch (_) {
    return null;
  }
}

/// The highest version that flowline's `forceUpdate` map marks as forced and
/// that this store already offers, i.e. no higher than [latestVersion].
///
/// A forced release stays the minimum version after newer, unforced releases
/// come out: anyone still below it has to update. Forced versions above
/// [latestVersion] are skipped because this store doesn't have them yet (the
/// map is shared by every store).
String? minimumForcedVersion(Map? forceUpdate, Object? latestVersion) {
  final latest = parseAppVersion(latestVersion);
  if (forceUpdate == null || latest == null) return null;

  String? minimumKey;
  Version? minimum;
  for (final entry in forceUpdate.entries) {
    if (entry.value != true) continue;
    final forced = parseAppVersion(entry.key);
    if (forced == null || forced > latest) continue;
    if (minimum == null || forced > minimum) {
      minimum = forced;
      minimumKey = entry.key as String;
    }
  }
  return minimumKey;
}
