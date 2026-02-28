import 'package:freezed_annotation/freezed_annotation.dart';

part 'hint.freezed.dart';
part 'hint.g.dart';

@freezed
class Hint with _$Hint {
  const factory Hint({
    @JsonKey(name: "title") String? title,
    @JsonKey(name: "desc") required String message,
  }) = _Hint;

  factory Hint.fromJson(Map<String, dynamic> json) => _$HintFromJson(json);
}
