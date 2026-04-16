import 'package:freezed_annotation/freezed_annotation.dart';

part 'hint.freezed.dart';
part 'hint.g.dart';

@freezed
class HintTranslation with _$HintTranslation {
  const factory HintTranslation({
    @JsonKey(name: "title") String? title,
    @JsonKey(name: "desc") required String desc,
  }) = _HintTranslation;

  factory HintTranslation.fromJson(Map<String, dynamic> json) =>
      _$HintTranslationFromJson(json);
}

@freezed
class Hint with _$Hint {
  const factory Hint({
    @JsonKey(name: "title") String? title,
    @JsonKey(name: "desc") required String message,
    @JsonKey(name: "translate") Map<String, dynamic>? translate,
  }) = _Hint;

  factory Hint.fromJson(Map<String, dynamic> json) => _$HintFromJson(json);
}
