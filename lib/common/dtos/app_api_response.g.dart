// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_api_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppApiResponseImpl _$$AppApiResponseImplFromJson(Map<String, dynamic> json) =>
    _$AppApiResponseImpl(
      version: Version.fromJson(json['version'] as Map<String, dynamic>),
      forceUpdate: Map<String, bool>.from(json['forceUpdate'] as Map),
      changeLog: (json['changeLog'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
      flowLine: AppApiResponseFlowLine.fromJson(
          json['flowLine'] as Map<String, dynamic>),
      testUrls:
          (json['testUrls'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$$AppApiResponseImplToJson(
        _$AppApiResponseImpl instance) =>
    <String, dynamic>{
      'version': instance.version,
      'forceUpdate': instance.forceUpdate,
      'changeLog': instance.changeLog,
      'flowLine': instance.flowLine,
      'testUrls': instance.testUrls,
    };

_$AppApiResponseFlowLineImpl _$$AppApiResponseFlowLineImplFromJson(
        Map<String, dynamic> json) =>
    _$AppApiResponseFlowLineImpl(
      startLine: (json['startLine'] as num).toInt(),
      flowLine: (json['flowLine'] as List<dynamic>)
          .map((e) => FlowLineElement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$AppApiResponseFlowLineImplToJson(
        _$AppApiResponseFlowLineImpl instance) =>
    <String, dynamic>{
      'startLine': instance.startLine,
      'flowLine': instance.flowLine,
    };

_$FlowLineElementImpl _$$FlowLineElementImplFromJson(
        Map<String, dynamic> json) =>
    _$FlowLineElementImpl(
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

Map<String, dynamic> _$$FlowLineElementImplToJson(
        _$FlowLineElementImpl instance) =>
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

_$VersionImpl _$$VersionImplFromJson(Map<String, dynamic> json) =>
    _$VersionImpl(
      github: json['github'] as String,
      testFlight: json['testFlight'] as String,
      appleStore: json['appleStore'] as String,
      googlePlay: json['googlePlay'] as String,
      microsoftStore: json['microsoftStore'] as String,
    );

Map<String, dynamic> _$$VersionImplToJson(_$VersionImpl instance) =>
    <String, dynamic>{
      'github': instance.github,
      'testFlight': instance.testFlight,
      'appleStore': instance.appleStore,
      'googlePlay': instance.googlePlay,
      'microsoftStore': instance.microsoftStore,
    };
