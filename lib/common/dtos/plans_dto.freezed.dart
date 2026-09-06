// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plans_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PlansResponse _$PlansResponseFromJson(Map<String, dynamic> json) {
  return _PlansResponse.fromJson(json);
}

/// @nodoc
mixin _$PlansResponse {
  @JsonKey(name: "id")
  int get id => throw _privateConstructorUsedError;
  @JsonKey(name: "name")
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: "duration_days")
  int get duration_days => throw _privateConstructorUsedError;
  @JsonKey(name: "bandwidth_limit")
  int get bandwidth_limit => throw _privateConstructorUsedError;
  @JsonKey(name: "price")
  double get price => throw _privateConstructorUsedError;

  /// Serializes this PlansResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlansResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlansResponseCopyWith<PlansResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlansResponseCopyWith<$Res> {
  factory $PlansResponseCopyWith(
    PlansResponse value,
    $Res Function(PlansResponse) then,
  ) = _$PlansResponseCopyWithImpl<$Res, PlansResponse>;
  @useResult
  $Res call({
    @JsonKey(name: "id") int id,
    @JsonKey(name: "name") String name,
    @JsonKey(name: "duration_days") int duration_days,
    @JsonKey(name: "bandwidth_limit") int bandwidth_limit,
    @JsonKey(name: "price") double price,
  });
}

/// @nodoc
class _$PlansResponseCopyWithImpl<$Res, $Val extends PlansResponse>
    implements $PlansResponseCopyWith<$Res> {
  _$PlansResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlansResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? duration_days = null,
    Object? bandwidth_limit = null,
    Object? price = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            duration_days: null == duration_days
                ? _value.duration_days
                : duration_days // ignore: cast_nullable_to_non_nullable
                      as int,
            bandwidth_limit: null == bandwidth_limit
                ? _value.bandwidth_limit
                : bandwidth_limit // ignore: cast_nullable_to_non_nullable
                      as int,
            price: null == price
                ? _value.price
                : price // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PlansResponseImplCopyWith<$Res>
    implements $PlansResponseCopyWith<$Res> {
  factory _$$PlansResponseImplCopyWith(
    _$PlansResponseImpl value,
    $Res Function(_$PlansResponseImpl) then,
  ) = __$$PlansResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: "id") int id,
    @JsonKey(name: "name") String name,
    @JsonKey(name: "duration_days") int duration_days,
    @JsonKey(name: "bandwidth_limit") int bandwidth_limit,
    @JsonKey(name: "price") double price,
  });
}

/// @nodoc
class __$$PlansResponseImplCopyWithImpl<$Res>
    extends _$PlansResponseCopyWithImpl<$Res, _$PlansResponseImpl>
    implements _$$PlansResponseImplCopyWith<$Res> {
  __$$PlansResponseImplCopyWithImpl(
    _$PlansResponseImpl _value,
    $Res Function(_$PlansResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlansResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? duration_days = null,
    Object? bandwidth_limit = null,
    Object? price = null,
  }) {
    return _then(
      _$PlansResponseImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        duration_days: null == duration_days
            ? _value.duration_days
            : duration_days // ignore: cast_nullable_to_non_nullable
                  as int,
        bandwidth_limit: null == bandwidth_limit
            ? _value.bandwidth_limit
            : bandwidth_limit // ignore: cast_nullable_to_non_nullable
                  as int,
        price: null == price
            ? _value.price
            : price // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PlansResponseImpl implements _PlansResponse {
  const _$PlansResponseImpl({
    @JsonKey(name: "id") required this.id,
    @JsonKey(name: "name") required this.name,
    @JsonKey(name: "duration_days") required this.duration_days,
    @JsonKey(name: "bandwidth_limit") required this.bandwidth_limit,
    @JsonKey(name: "price") required this.price,
  });

  factory _$PlansResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlansResponseImplFromJson(json);

  @override
  @JsonKey(name: "id")
  final int id;
  @override
  @JsonKey(name: "name")
  final String name;
  @override
  @JsonKey(name: "duration_days")
  final int duration_days;
  @override
  @JsonKey(name: "bandwidth_limit")
  final int bandwidth_limit;
  @override
  @JsonKey(name: "price")
  final double price;

  @override
  String toString() {
    return 'PlansResponse(id: $id, name: $name, duration_days: $duration_days, bandwidth_limit: $bandwidth_limit, price: $price)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlansResponseImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.duration_days, duration_days) ||
                other.duration_days == duration_days) &&
            (identical(other.bandwidth_limit, bandwidth_limit) ||
                other.bandwidth_limit == bandwidth_limit) &&
            (identical(other.price, price) || other.price == price));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, duration_days, bandwidth_limit, price);

  /// Create a copy of PlansResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlansResponseImplCopyWith<_$PlansResponseImpl> get copyWith =>
      __$$PlansResponseImplCopyWithImpl<_$PlansResponseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlansResponseImplToJson(this);
  }
}

abstract class _PlansResponse implements PlansResponse {
  const factory _PlansResponse({
    @JsonKey(name: "id") required final int id,
    @JsonKey(name: "name") required final String name,
    @JsonKey(name: "duration_days") required final int duration_days,
    @JsonKey(name: "bandwidth_limit") required final int bandwidth_limit,
    @JsonKey(name: "price") required final double price,
  }) = _$PlansResponseImpl;

  factory _PlansResponse.fromJson(Map<String, dynamic> json) =
      _$PlansResponseImpl.fromJson;

  @override
  @JsonKey(name: "id")
  int get id;
  @override
  @JsonKey(name: "name")
  String get name;
  @override
  @JsonKey(name: "duration_days")
  int get duration_days;
  @override
  @JsonKey(name: "bandwidth_limit")
  int get bandwidth_limit;
  @override
  @JsonKey(name: "price")
  double get price;

  /// Create a copy of PlansResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlansResponseImplCopyWith<_$PlansResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlansListResponse _$PlansListResponseFromJson(Map<String, dynamic> json) {
  return _PlansListResponse.fromJson(json);
}

/// @nodoc
mixin _$PlansListResponse {
  @JsonKey(name: "configs")
  List<PlansResponse> get configs => throw _privateConstructorUsedError;

  /// Serializes this PlansListResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlansListResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlansListResponseCopyWith<PlansListResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlansListResponseCopyWith<$Res> {
  factory $PlansListResponseCopyWith(
    PlansListResponse value,
    $Res Function(PlansListResponse) then,
  ) = _$PlansListResponseCopyWithImpl<$Res, PlansListResponse>;
  @useResult
  $Res call({@JsonKey(name: "configs") List<PlansResponse> configs});
}

/// @nodoc
class _$PlansListResponseCopyWithImpl<$Res, $Val extends PlansListResponse>
    implements $PlansListResponseCopyWith<$Res> {
  _$PlansListResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlansListResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? configs = null}) {
    return _then(
      _value.copyWith(
            configs: null == configs
                ? _value.configs
                : configs // ignore: cast_nullable_to_non_nullable
                      as List<PlansResponse>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PlansListResponseImplCopyWith<$Res>
    implements $PlansListResponseCopyWith<$Res> {
  factory _$$PlansListResponseImplCopyWith(
    _$PlansListResponseImpl value,
    $Res Function(_$PlansListResponseImpl) then,
  ) = __$$PlansListResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({@JsonKey(name: "configs") List<PlansResponse> configs});
}

/// @nodoc
class __$$PlansListResponseImplCopyWithImpl<$Res>
    extends _$PlansListResponseCopyWithImpl<$Res, _$PlansListResponseImpl>
    implements _$$PlansListResponseImplCopyWith<$Res> {
  __$$PlansListResponseImplCopyWithImpl(
    _$PlansListResponseImpl _value,
    $Res Function(_$PlansListResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlansListResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? configs = null}) {
    return _then(
      _$PlansListResponseImpl(
        configs: null == configs
            ? _value._configs
            : configs // ignore: cast_nullable_to_non_nullable
                  as List<PlansResponse>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PlansListResponseImpl implements _PlansListResponse {
  const _$PlansListResponseImpl({
    @JsonKey(name: "configs") required final List<PlansResponse> configs,
  }) : _configs = configs;

  factory _$PlansListResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlansListResponseImplFromJson(json);

  final List<PlansResponse> _configs;
  @override
  @JsonKey(name: "configs")
  List<PlansResponse> get configs {
    if (_configs is EqualUnmodifiableListView) return _configs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_configs);
  }

  @override
  String toString() {
    return 'PlansListResponse(configs: $configs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlansListResponseImpl &&
            const DeepCollectionEquality().equals(other._configs, _configs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_configs));

  /// Create a copy of PlansListResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlansListResponseImplCopyWith<_$PlansListResponseImpl> get copyWith =>
      __$$PlansListResponseImplCopyWithImpl<_$PlansListResponseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PlansListResponseImplToJson(this);
  }
}

abstract class _PlansListResponse implements PlansListResponse {
  const factory _PlansListResponse({
    @JsonKey(name: "configs") required final List<PlansResponse> configs,
  }) = _$PlansListResponseImpl;

  factory _PlansListResponse.fromJson(Map<String, dynamic> json) =
      _$PlansListResponseImpl.fromJson;

  @override
  @JsonKey(name: "configs")
  List<PlansResponse> get configs;

  /// Create a copy of PlansListResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlansListResponseImplCopyWith<_$PlansListResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
