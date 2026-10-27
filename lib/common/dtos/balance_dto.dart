import 'package:freezed_annotation/freezed_annotation.dart';

part 'balance_dto.freezed.dart';
part 'balance_dto.g.dart';

@freezed
class BalanceResponse with _$BalanceResponse {
  const factory BalanceResponse({
    @JsonKey(name: 'balance') required double balance,
  }) = _BalanceResponse;

  factory BalanceResponse.fromJson(Map<String, dynamic> json) =>
      _$BalanceResponseFromJson(json);
}
