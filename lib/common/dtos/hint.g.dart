// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hint.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$HintTranslationImpl _$$HintTranslationImplFromJson(
  Map<String, dynamic> json,
) => _$HintTranslationImpl(
  title: json['title'] as String?,
  desc: json['desc'] as String,
);

Map<String, dynamic> _$$HintTranslationImplToJson(
  _$HintTranslationImpl instance,
) => <String, dynamic>{'title': instance.title, 'desc': instance.desc};

_$HintImpl _$$HintImplFromJson(Map<String, dynamic> json) => _$HintImpl(
  title: json['title'] as String?,
  message: json['desc'] as String,
  translate: json['translate'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$$HintImplToJson(_$HintImpl instance) =>
    <String, dynamic>{
      'title': instance.title,
      'desc': instance.message,
      'translate': instance.translate,
    };
