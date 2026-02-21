import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_api_response.freezed.dart';
part 'app_api_response.g.dart';

@freezed
abstract class AppApiResponse with _$AppApiResponse {
  const factory AppApiResponse({
    @JsonKey(name: "version") required Version version,
    @JsonKey(name: "forceUpdate") required Map<String, bool> forceUpdate,
    @JsonKey(name: "changeLog") required Map<String, List<String>> changeLog,
    @JsonKey(name: "flowLine") required AppApiResponseFlowLine flowLine,
    @JsonKey(name: "testUrls") required List<String> testUrls,
  }) = _AppApiResponse;

  factory AppApiResponse.fromJson(Map<String, dynamic> json) =>
      _$AppApiResponseFromJson(json);
}

@freezed
abstract class AppApiResponseFlowLine with _$AppApiResponseFlowLine {
  const factory AppApiResponseFlowLine({
    @JsonKey(name: "startLine") required int startLine,
    @JsonKey(name: "flowLine") required List<FlowLineElement> flowLine,
  }) = _AppApiResponseFlowLine;

  factory AppApiResponseFlowLine.fromJson(Map<String, dynamic> json) =>
      _$AppApiResponseFlowLineFromJson(json);
}

@freezed
abstract class FlowLineElement with _$FlowLineElement {
  const factory FlowLineElement({
    @JsonKey(name: "enabled") required bool enabled,
    @JsonKey(name: "type") required String type,
    @JsonKey(name: "provider") required String provider,
    @JsonKey(name: "endpoint") String? endpoint,
    @JsonKey(name: "dns") String? dns,
    @JsonKey(name: "scanner") bool? scanner,
    @JsonKey(name: "scanner_type") String? scannerType,
    @JsonKey(name: "scanner_timeout") int? scannerTimeout,
    @JsonKey(name: "psiphon") bool? psiphon,
    @JsonKey(name: "psiphon_country") String? psiphonCountry,
    @JsonKey(name: "gool") bool? gool,
    @JsonKey(name: "url") String? url,
  }) = _FlowLineElement;

  factory FlowLineElement.fromJson(Map<String, dynamic> json) =>
      _$FlowLineElementFromJson(json);
}

@freezed
abstract class Version with _$Version {
  const factory Version({
    @JsonKey(name: "github") required String github,
    @JsonKey(name: "testFlight") required String testFlight,
    @JsonKey(name: "appleStore") required String appleStore,
    @JsonKey(name: "googlePlay") required String googlePlay,
    @JsonKey(name: "microsoftStore") required String microsoftStore,
  }) = _Version;

  factory Version.fromJson(Map<String, dynamic> json) =>
      _$VersionFromJson(json);
}
