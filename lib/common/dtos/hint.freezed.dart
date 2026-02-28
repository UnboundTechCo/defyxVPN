// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'hint.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Hint _$HintFromJson(Map<String, dynamic> json) {
  return _Hint.fromJson(json);
}

/// @nodoc
mixin _$Hint {
  @JsonKey(name: "title")
  String? get title => throw _privateConstructorUsedError;
  @JsonKey(name: "desc")
  String get message => throw _privateConstructorUsedError;

  /// Serializes this Hint to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Hint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HintCopyWith<Hint> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HintCopyWith<$Res> {
  factory $HintCopyWith(Hint value, $Res Function(Hint) then) =
      _$HintCopyWithImpl<$Res, Hint>;
  @useResult
  $Res call(
      {@JsonKey(name: "title") String? title,
      @JsonKey(name: "desc") String message});
}

/// @nodoc
class _$HintCopyWithImpl<$Res, $Val extends Hint>
    implements $HintCopyWith<$Res> {
  _$HintCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Hint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = freezed,
    Object? message = null,
  }) {
    return _then(_value.copyWith(
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$HintImplCopyWith<$Res> implements $HintCopyWith<$Res> {
  factory _$$HintImplCopyWith(
          _$HintImpl value, $Res Function(_$HintImpl) then) =
      __$$HintImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: "title") String? title,
      @JsonKey(name: "desc") String message});
}

/// @nodoc
class __$$HintImplCopyWithImpl<$Res>
    extends _$HintCopyWithImpl<$Res, _$HintImpl>
    implements _$$HintImplCopyWith<$Res> {
  __$$HintImplCopyWithImpl(_$HintImpl _value, $Res Function(_$HintImpl) _then)
      : super(_value, _then);

  /// Create a copy of Hint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = freezed,
    Object? message = null,
  }) {
    return _then(_$HintImpl(
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$HintImpl implements _Hint {
  const _$HintImpl(
      {@JsonKey(name: "title") this.title,
      @JsonKey(name: "desc") required this.message});

  factory _$HintImpl.fromJson(Map<String, dynamic> json) =>
      _$$HintImplFromJson(json);

  @override
  @JsonKey(name: "title")
  final String? title;
  @override
  @JsonKey(name: "desc")
  final String message;

  @override
  String toString() {
    return 'Hint(title: $title, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HintImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, title, message);

  /// Create a copy of Hint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HintImplCopyWith<_$HintImpl> get copyWith =>
      __$$HintImplCopyWithImpl<_$HintImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$HintImplToJson(
      this,
    );
  }
}

abstract class _Hint implements Hint {
  const factory _Hint(
      {@JsonKey(name: "title") final String? title,
      @JsonKey(name: "desc") required final String message}) = _$HintImpl;

  factory _Hint.fromJson(Map<String, dynamic> json) = _$HintImpl.fromJson;

  @override
  @JsonKey(name: "title")
  String? get title;
  @override
  @JsonKey(name: "desc")
  String get message;

  /// Create a copy of Hint
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HintImplCopyWith<_$HintImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
