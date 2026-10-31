import 'package:freezed_annotation/freezed_annotation.dart';

part 'plans_dto.freezed.dart';
part 'plans_dto.g.dart';

@freezed
class PlansResponse with _$PlansResponse {
  const factory PlansResponse({
    @JsonKey(name: "id") required int id,
    @JsonKey(name: "name") required String name,
    @JsonKey(name: "description") required String description,
    @JsonKey(name: "duration_days") required int duration_days,
    @JsonKey(name: "bandwidth_limit") required int bandwidth_limit,
    @JsonKey(name: "price") required double price,
  }) = _PlansResponse;

  factory PlansResponse.fromJson(Map<String, dynamic> json) =>
      _$PlansResponseFromJson(json);
}

@freezed
class PlansListResponse with _$PlansListResponse {
  const factory PlansListResponse({
    @JsonKey(name: "configs") required List<PlansResponse> configs,
  }) = _PlansListResponse;

  factory PlansListResponse.fromJson(Map<String, dynamic> json) =>
      _$PlansListResponseFromJson(json);
}
