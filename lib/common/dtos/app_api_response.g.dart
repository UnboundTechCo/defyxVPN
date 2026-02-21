// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_api_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppApiResponse _$AppApiResponseFromJson(Map<String, dynamic> json) =>
    _AppApiResponse(
      version: Version.fromJson(json['version'] as Map<String, dynamic>),
      forceUpdate: Map<String, bool>.from(json['forceUpdate'] as Map),
      changeLog: (json['changeLog'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
      flowLine: AppApiResponseFlowLine.fromJson(
        json['flowLine'] as Map<String, dynamic>,
      ),
      testUrls: (json['testUrls'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$AppApiResponseToJson(_AppApiResponse instance) =>
    <String, dynamic>{
      'version': instance.version,
      'forceUpdate': instance.forceUpdate,
      'changeLog': instance.changeLog,
      'flowLine': instance.flowLine,
      'testUrls': instance.testUrls,
    };

_AppApiResponseFlowLine _$AppApiResponseFlowLineFromJson(
  Map<String, dynamic> json,
) => _AppApiResponseFlowLine(
  startLine: (json['startLine'] as num).toInt(),
  flowLine: (json['flowLine'] as List<dynamic>)
      .map((e) => FlowLineElement.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$AppApiResponseFlowLineToJson(
  _AppApiResponseFlowLine instance,
) => <String, dynamic>{
  'startLine': instance.startLine,
  'flowLine': instance.flowLine,
};

_FlowLineElement _$FlowLineElementFromJson(Map<String, dynamic> json) =>
    _FlowLineElement(
      enabled: json['enabled'] as bool,
      type: json['type'] as String,
      provider: json['provider'] as String,
      endpoint: json['endpoint'] as String?,
      dns: json['dns'] as String?,
      scanner: json['scanner'] as bool?,
      scannerType: json['scanner_type'] as String?,
      scannerTimeout: (json['scanner_timeout'] as num?)?.toInt(),
      psiphon: json['psiphon'] as bool?,
      psiphonCountry: json['psiphon_country'] as String?,
      gool: json['gool'] as bool?,
      url: json['url'] as String?,
    );

Map<String, dynamic> _$FlowLineElementToJson(_FlowLineElement instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'type': instance.type,
      'provider': instance.provider,
      'endpoint': instance.endpoint,
      'dns': instance.dns,
      'scanner': instance.scanner,
      'scanner_type': instance.scannerType,
      'scanner_timeout': instance.scannerTimeout,
      'psiphon': instance.psiphon,
      'psiphon_country': instance.psiphonCountry,
      'gool': instance.gool,
      'url': instance.url,
    };

_Version _$VersionFromJson(Map<String, dynamic> json) => _Version(
  github: json['github'] as String,
  testFlight: json['testFlight'] as String,
  appleStore: json['appleStore'] as String,
  googlePlay: json['googlePlay'] as String,
  microsoftStore: json['microsoftStore'] as String,
);

Map<String, dynamic> _$VersionToJson(_Version instance) => <String, dynamic>{
  'github': instance.github,
  'testFlight': instance.testFlight,
  'appleStore': instance.appleStore,
  'googlePlay': instance.googlePlay,
  'microsoftStore': instance.microsoftStore,
};
