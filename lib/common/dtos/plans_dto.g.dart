// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plans_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PlansResponseImpl _$$PlansResponseImplFromJson(Map<String, dynamic> json) =>
    _$PlansResponseImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      duration_days: (json['duration_days'] as num).toInt(),
      bandwidth_limit: (json['bandwidth_limit'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
    );

Map<String, dynamic> _$$PlansResponseImplToJson(_$PlansResponseImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'duration_days': instance.duration_days,
      'bandwidth_limit': instance.bandwidth_limit,
      'price': instance.price,
    };

_$PlansListResponseImpl _$$PlansListResponseImplFromJson(
  Map<String, dynamic> json,
) => _$PlansListResponseImpl(
  configs: (json['configs'] as List<dynamic>)
      .map((e) => PlansResponse.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$$PlansListResponseImplToJson(
  _$PlansListResponseImpl instance,
) => <String, dynamic>{'configs': instance.configs};
