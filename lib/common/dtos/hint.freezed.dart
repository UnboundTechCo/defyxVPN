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
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

HintTranslation _$HintTranslationFromJson(Map<String, dynamic> json) {
  return _HintTranslation.fromJson(json);
}

/// @nodoc
mixin _$HintTranslation {
  @JsonKey(name: "title")
  String? get title => throw _privateConstructorUsedError;
  @JsonKey(name: "desc")
  String get desc => throw _privateConstructorUsedError;

  /// Serializes this HintTranslation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HintTranslation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HintTranslationCopyWith<HintTranslation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HintTranslationCopyWith<$Res> {
  factory $HintTranslationCopyWith(
    HintTranslation value,
    $Res Function(HintTranslation) then,
  ) = _$HintTranslationCopyWithImpl<$Res, HintTranslation>;
  @useResult
  $Res call({
    @JsonKey(name: "title") String? title,
    @JsonKey(name: "desc") String desc,
  });
}

/// @nodoc
class _$HintTranslationCopyWithImpl<$Res, $Val extends HintTranslation>
    implements $HintTranslationCopyWith<$Res> {
  _$HintTranslationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HintTranslation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? title = freezed, Object? desc = null}) {
    return _then(
      _value.copyWith(
            title: freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String?,
            desc: null == desc
                ? _value.desc
                : desc // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$HintTranslationImplCopyWith<$Res>
    implements $HintTranslationCopyWith<$Res> {
  factory _$$HintTranslationImplCopyWith(
    _$HintTranslationImpl value,
    $Res Function(_$HintTranslationImpl) then,
  ) = __$$HintTranslationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: "title") String? title,
    @JsonKey(name: "desc") String desc,
  });
}

/// @nodoc
class __$$HintTranslationImplCopyWithImpl<$Res>
    extends _$HintTranslationCopyWithImpl<$Res, _$HintTranslationImpl>
    implements _$$HintTranslationImplCopyWith<$Res> {
  __$$HintTranslationImplCopyWithImpl(
    _$HintTranslationImpl _value,
    $Res Function(_$HintTranslationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HintTranslation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? title = freezed, Object? desc = null}) {
    return _then(
      _$HintTranslationImpl(
        title: freezed == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
        desc: null == desc
            ? _value.desc
            : desc // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$HintTranslationImpl implements _HintTranslation {
  const _$HintTranslationImpl({
    @JsonKey(name: "title") this.title,
    @JsonKey(name: "desc") required this.desc,
  });

  factory _$HintTranslationImpl.fromJson(Map<String, dynamic> json) =>
      _$$HintTranslationImplFromJson(json);

  @override
  @JsonKey(name: "title")
  final String? title;
  @override
  @JsonKey(name: "desc")
  final String desc;

  @override
  String toString() {
    return 'HintTranslation(title: $title, desc: $desc)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HintTranslationImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.desc, desc) || other.desc == desc));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, title, desc);

  /// Create a copy of HintTranslation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HintTranslationImplCopyWith<_$HintTranslationImpl> get copyWith =>
      __$$HintTranslationImplCopyWithImpl<_$HintTranslationImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$HintTranslationImplToJson(this);
  }
}

abstract class _HintTranslation implements HintTranslation {
  const factory _HintTranslation({
    @JsonKey(name: "title") final String? title,
    @JsonKey(name: "desc") required final String desc,
  }) = _$HintTranslationImpl;

  factory _HintTranslation.fromJson(Map<String, dynamic> json) =
      _$HintTranslationImpl.fromJson;

  @override
  @JsonKey(name: "title")
  String? get title;
  @override
  @JsonKey(name: "desc")
  String get desc;

  /// Create a copy of HintTranslation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HintTranslationImplCopyWith<_$HintTranslationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Hint _$HintFromJson(Map<String, dynamic> json) {
  return _Hint.fromJson(json);
}

/// @nodoc
mixin _$Hint {
  @JsonKey(name: "title")
  String? get title => throw _privateConstructorUsedError;
  @JsonKey(name: "desc")
  String get message => throw _privateConstructorUsedError;
  @JsonKey(name: "translate")
  Map<String, dynamic>? get translate => throw _privateConstructorUsedError;

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
  $Res call({
    @JsonKey(name: "title") String? title,
    @JsonKey(name: "desc") String message,
    @JsonKey(name: "translate") Map<String, dynamic>? translate,
  });
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
    Object? translate = freezed,
  }) {
    return _then(
      _value.copyWith(
            title: freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String?,
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
            translate: freezed == translate
                ? _value.translate
                : translate // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$HintImplCopyWith<$Res> implements $HintCopyWith<$Res> {
  factory _$$HintImplCopyWith(
    _$HintImpl value,
    $Res Function(_$HintImpl) then,
  ) = __$$HintImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: "title") String? title,
    @JsonKey(name: "desc") String message,
    @JsonKey(name: "translate") Map<String, dynamic>? translate,
  });
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
    Object? translate = freezed,
  }) {
    return _then(
      _$HintImpl(
        title: freezed == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
        translate: freezed == translate
            ? _value._translate
            : translate // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$HintImpl implements _Hint {
  const _$HintImpl({
    @JsonKey(name: "title") this.title,
    @JsonKey(name: "desc") required this.message,
    @JsonKey(name: "translate") final Map<String, dynamic>? translate,
  }) : _translate = translate;

  factory _$HintImpl.fromJson(Map<String, dynamic> json) =>
      _$$HintImplFromJson(json);

  @override
  @JsonKey(name: "title")
  final String? title;
  @override
  @JsonKey(name: "desc")
  final String message;
  final Map<String, dynamic>? _translate;
  @override
  @JsonKey(name: "translate")
  Map<String, dynamic>? get translate {
    final value = _translate;
    if (value == null) return null;
    if (_translate is EqualUnmodifiableMapView) return _translate;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'Hint(title: $title, message: $message, translate: $translate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HintImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.message, message) || other.message == message) &&
            const DeepCollectionEquality().equals(
              other._translate,
              _translate,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    title,
    message,
    const DeepCollectionEquality().hash(_translate),
  );

  /// Create a copy of Hint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HintImplCopyWith<_$HintImpl> get copyWith =>
      __$$HintImplCopyWithImpl<_$HintImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$HintImplToJson(this);
  }
}

abstract class _Hint implements Hint {
  const factory _Hint({
    @JsonKey(name: "title") final String? title,
    @JsonKey(name: "desc") required final String message,
    @JsonKey(name: "translate") final Map<String, dynamic>? translate,
  }) = _$HintImpl;

  factory _Hint.fromJson(Map<String, dynamic> json) = _$HintImpl.fromJson;

  @override
  @JsonKey(name: "title")
  String? get title;
  @override
  @JsonKey(name: "desc")
  String get message;
  @override
  @JsonKey(name: "translate")
  Map<String, dynamic>? get translate;

  /// Create a copy of Hint
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HintImplCopyWith<_$HintImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
