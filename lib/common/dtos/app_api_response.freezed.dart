// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_api_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AppApiResponse _$AppApiResponseFromJson(Map<String, dynamic> json) {
  return _AppApiResponse.fromJson(json);
}

/// @nodoc
mixin _$AppApiResponse {
  @JsonKey(name: "version")
  Version get version => throw _privateConstructorUsedError;
  @JsonKey(name: "forceUpdate")
  Map<String, bool> get forceUpdate => throw _privateConstructorUsedError;
  @JsonKey(name: "changeLog")
  Map<String, List<String>> get changeLog => throw _privateConstructorUsedError;
  @JsonKey(name: "flowLine")
  AppApiResponseFlowLine get flowLine => throw _privateConstructorUsedError;
  @JsonKey(name: "testUrls")
  List<String> get testUrls => throw _privateConstructorUsedError;

  /// Serializes this AppApiResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppApiResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppApiResponseCopyWith<AppApiResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppApiResponseCopyWith<$Res> {
  factory $AppApiResponseCopyWith(
          AppApiResponse value, $Res Function(AppApiResponse) then) =
      _$AppApiResponseCopyWithImpl<$Res, AppApiResponse>;
  @useResult
  $Res call(
      {@JsonKey(name: "version") Version version,
      @JsonKey(name: "forceUpdate") Map<String, bool> forceUpdate,
      @JsonKey(name: "changeLog") Map<String, List<String>> changeLog,
      @JsonKey(name: "flowLine") AppApiResponseFlowLine flowLine,
      @JsonKey(name: "testUrls") List<String> testUrls});

  $VersionCopyWith<$Res> get version;
  $AppApiResponseFlowLineCopyWith<$Res> get flowLine;
}

/// @nodoc
class _$AppApiResponseCopyWithImpl<$Res, $Val extends AppApiResponse>
    implements $AppApiResponseCopyWith<$Res> {
  _$AppApiResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppApiResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? forceUpdate = null,
    Object? changeLog = null,
    Object? flowLine = null,
    Object? testUrls = null,
  }) {
    return _then(_value.copyWith(
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as Version,
      forceUpdate: null == forceUpdate
          ? _value.forceUpdate
          : forceUpdate // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      changeLog: null == changeLog
          ? _value.changeLog
          : changeLog // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
      flowLine: null == flowLine
          ? _value.flowLine
          : flowLine // ignore: cast_nullable_to_non_nullable
              as AppApiResponseFlowLine,
      testUrls: null == testUrls
          ? _value.testUrls
          : testUrls // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }

  /// Create a copy of AppApiResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $VersionCopyWith<$Res> get version {
    return $VersionCopyWith<$Res>(_value.version, (value) {
      return _then(_value.copyWith(version: value) as $Val);
    });
  }

  /// Create a copy of AppApiResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AppApiResponseFlowLineCopyWith<$Res> get flowLine {
    return $AppApiResponseFlowLineCopyWith<$Res>(_value.flowLine, (value) {
      return _then(_value.copyWith(flowLine: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AppApiResponseImplCopyWith<$Res>
    implements $AppApiResponseCopyWith<$Res> {
  factory _$$AppApiResponseImplCopyWith(_$AppApiResponseImpl value,
          $Res Function(_$AppApiResponseImpl) then) =
      __$$AppApiResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: "version") Version version,
      @JsonKey(name: "forceUpdate") Map<String, bool> forceUpdate,
      @JsonKey(name: "changeLog") Map<String, List<String>> changeLog,
      @JsonKey(name: "flowLine") AppApiResponseFlowLine flowLine,
      @JsonKey(name: "testUrls") List<String> testUrls});

  @override
  $VersionCopyWith<$Res> get version;
  @override
  $AppApiResponseFlowLineCopyWith<$Res> get flowLine;
}

/// @nodoc
class __$$AppApiResponseImplCopyWithImpl<$Res>
    extends _$AppApiResponseCopyWithImpl<$Res, _$AppApiResponseImpl>
    implements _$$AppApiResponseImplCopyWith<$Res> {
  __$$AppApiResponseImplCopyWithImpl(
      _$AppApiResponseImpl _value, $Res Function(_$AppApiResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppApiResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? forceUpdate = null,
    Object? changeLog = null,
    Object? flowLine = null,
    Object? testUrls = null,
  }) {
    return _then(_$AppApiResponseImpl(
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as Version,
      forceUpdate: null == forceUpdate
          ? _value._forceUpdate
          : forceUpdate // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      changeLog: null == changeLog
          ? _value._changeLog
          : changeLog // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
      flowLine: null == flowLine
          ? _value.flowLine
          : flowLine // ignore: cast_nullable_to_non_nullable
              as AppApiResponseFlowLine,
      testUrls: null == testUrls
          ? _value._testUrls
          : testUrls // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AppApiResponseImpl implements _AppApiResponse {
  const _$AppApiResponseImpl(
      {@JsonKey(name: "version") required this.version,
      @JsonKey(name: "forceUpdate")
      required final Map<String, bool> forceUpdate,
      @JsonKey(name: "changeLog")
      required final Map<String, List<String>> changeLog,
      @JsonKey(name: "flowLine") required this.flowLine,
      @JsonKey(name: "testUrls") required final List<String> testUrls})
      : _forceUpdate = forceUpdate,
        _changeLog = changeLog,
        _testUrls = testUrls;

  factory _$AppApiResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppApiResponseImplFromJson(json);

  @override
  @JsonKey(name: "version")
  final Version version;
  final Map<String, bool> _forceUpdate;
  @override
  @JsonKey(name: "forceUpdate")
  Map<String, bool> get forceUpdate {
    if (_forceUpdate is EqualUnmodifiableMapView) return _forceUpdate;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_forceUpdate);
  }

  final Map<String, List<String>> _changeLog;
  @override
  @JsonKey(name: "changeLog")
  Map<String, List<String>> get changeLog {
    if (_changeLog is EqualUnmodifiableMapView) return _changeLog;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_changeLog);
  }

  @override
  @JsonKey(name: "flowLine")
  final AppApiResponseFlowLine flowLine;
  final List<String> _testUrls;
  @override
  @JsonKey(name: "testUrls")
  List<String> get testUrls {
    if (_testUrls is EqualUnmodifiableListView) return _testUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_testUrls);
  }

  @override
  String toString() {
    return 'AppApiResponse(version: $version, forceUpdate: $forceUpdate, changeLog: $changeLog, flowLine: $flowLine, testUrls: $testUrls)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppApiResponseImpl &&
            (identical(other.version, version) || other.version == version) &&
            const DeepCollectionEquality()
                .equals(other._forceUpdate, _forceUpdate) &&
            const DeepCollectionEquality()
                .equals(other._changeLog, _changeLog) &&
            (identical(other.flowLine, flowLine) ||
                other.flowLine == flowLine) &&
            const DeepCollectionEquality().equals(other._testUrls, _testUrls));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      version,
      const DeepCollectionEquality().hash(_forceUpdate),
      const DeepCollectionEquality().hash(_changeLog),
      flowLine,
      const DeepCollectionEquality().hash(_testUrls));

  /// Create a copy of AppApiResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppApiResponseImplCopyWith<_$AppApiResponseImpl> get copyWith =>
      __$$AppApiResponseImplCopyWithImpl<_$AppApiResponseImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppApiResponseImplToJson(
      this,
    );
  }
}

abstract class _AppApiResponse implements AppApiResponse {
  const factory _AppApiResponse(
      {@JsonKey(name: "version") required final Version version,
      @JsonKey(name: "forceUpdate")
      required final Map<String, bool> forceUpdate,
      @JsonKey(name: "changeLog")
      required final Map<String, List<String>> changeLog,
      @JsonKey(name: "flowLine") required final AppApiResponseFlowLine flowLine,
      @JsonKey(name: "testUrls")
      required final List<String> testUrls}) = _$AppApiResponseImpl;

  factory _AppApiResponse.fromJson(Map<String, dynamic> json) =
      _$AppApiResponseImpl.fromJson;

  @override
  @JsonKey(name: "version")
  Version get version;
  @override
  @JsonKey(name: "forceUpdate")
  Map<String, bool> get forceUpdate;
  @override
  @JsonKey(name: "changeLog")
  Map<String, List<String>> get changeLog;
  @override
  @JsonKey(name: "flowLine")
  AppApiResponseFlowLine get flowLine;
  @override
  @JsonKey(name: "testUrls")
  List<String> get testUrls;

  /// Create a copy of AppApiResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppApiResponseImplCopyWith<_$AppApiResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AppApiResponseFlowLine _$AppApiResponseFlowLineFromJson(
    Map<String, dynamic> json) {
  return _AppApiResponseFlowLine.fromJson(json);
}

/// @nodoc
mixin _$AppApiResponseFlowLine {
  @JsonKey(name: "startLine")
  int get startLine => throw _privateConstructorUsedError;
  @JsonKey(name: "flowLine")
  List<FlowLineElement> get flowLine => throw _privateConstructorUsedError;

  /// Serializes this AppApiResponseFlowLine to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppApiResponseFlowLine
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppApiResponseFlowLineCopyWith<AppApiResponseFlowLine> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppApiResponseFlowLineCopyWith<$Res> {
  factory $AppApiResponseFlowLineCopyWith(AppApiResponseFlowLine value,
          $Res Function(AppApiResponseFlowLine) then) =
      _$AppApiResponseFlowLineCopyWithImpl<$Res, AppApiResponseFlowLine>;
  @useResult
  $Res call(
      {@JsonKey(name: "startLine") int startLine,
      @JsonKey(name: "flowLine") List<FlowLineElement> flowLine});
}

/// @nodoc
class _$AppApiResponseFlowLineCopyWithImpl<$Res,
        $Val extends AppApiResponseFlowLine>
    implements $AppApiResponseFlowLineCopyWith<$Res> {
  _$AppApiResponseFlowLineCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppApiResponseFlowLine
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? startLine = null,
    Object? flowLine = null,
  }) {
    return _then(_value.copyWith(
      startLine: null == startLine
          ? _value.startLine
          : startLine // ignore: cast_nullable_to_non_nullable
              as int,
      flowLine: null == flowLine
          ? _value.flowLine
          : flowLine // ignore: cast_nullable_to_non_nullable
              as List<FlowLineElement>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AppApiResponseFlowLineImplCopyWith<$Res>
    implements $AppApiResponseFlowLineCopyWith<$Res> {
  factory _$$AppApiResponseFlowLineImplCopyWith(
          _$AppApiResponseFlowLineImpl value,
          $Res Function(_$AppApiResponseFlowLineImpl) then) =
      __$$AppApiResponseFlowLineImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: "startLine") int startLine,
      @JsonKey(name: "flowLine") List<FlowLineElement> flowLine});
}

/// @nodoc
class __$$AppApiResponseFlowLineImplCopyWithImpl<$Res>
    extends _$AppApiResponseFlowLineCopyWithImpl<$Res,
        _$AppApiResponseFlowLineImpl>
    implements _$$AppApiResponseFlowLineImplCopyWith<$Res> {
  __$$AppApiResponseFlowLineImplCopyWithImpl(
      _$AppApiResponseFlowLineImpl _value,
      $Res Function(_$AppApiResponseFlowLineImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppApiResponseFlowLine
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? startLine = null,
    Object? flowLine = null,
  }) {
    return _then(_$AppApiResponseFlowLineImpl(
      startLine: null == startLine
          ? _value.startLine
          : startLine // ignore: cast_nullable_to_non_nullable
              as int,
      flowLine: null == flowLine
          ? _value._flowLine
          : flowLine // ignore: cast_nullable_to_non_nullable
              as List<FlowLineElement>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AppApiResponseFlowLineImpl implements _AppApiResponseFlowLine {
  const _$AppApiResponseFlowLineImpl(
      {@JsonKey(name: "startLine") required this.startLine,
      @JsonKey(name: "flowLine") required final List<FlowLineElement> flowLine})
      : _flowLine = flowLine;

  factory _$AppApiResponseFlowLineImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppApiResponseFlowLineImplFromJson(json);

  @override
  @JsonKey(name: "startLine")
  final int startLine;
  final List<FlowLineElement> _flowLine;
  @override
  @JsonKey(name: "flowLine")
  List<FlowLineElement> get flowLine {
    if (_flowLine is EqualUnmodifiableListView) return _flowLine;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_flowLine);
  }

  @override
  String toString() {
    return 'AppApiResponseFlowLine(startLine: $startLine, flowLine: $flowLine)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppApiResponseFlowLineImpl &&
            (identical(other.startLine, startLine) ||
                other.startLine == startLine) &&
            const DeepCollectionEquality().equals(other._flowLine, _flowLine));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, startLine, const DeepCollectionEquality().hash(_flowLine));

  /// Create a copy of AppApiResponseFlowLine
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppApiResponseFlowLineImplCopyWith<_$AppApiResponseFlowLineImpl>
      get copyWith => __$$AppApiResponseFlowLineImplCopyWithImpl<
          _$AppApiResponseFlowLineImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppApiResponseFlowLineImplToJson(
      this,
    );
  }
}

abstract class _AppApiResponseFlowLine implements AppApiResponseFlowLine {
  const factory _AppApiResponseFlowLine(
          {@JsonKey(name: "startLine") required final int startLine,
          @JsonKey(name: "flowLine")
          required final List<FlowLineElement> flowLine}) =
      _$AppApiResponseFlowLineImpl;

  factory _AppApiResponseFlowLine.fromJson(Map<String, dynamic> json) =
      _$AppApiResponseFlowLineImpl.fromJson;

  @override
  @JsonKey(name: "startLine")
  int get startLine;
  @override
  @JsonKey(name: "flowLine")
  List<FlowLineElement> get flowLine;

  /// Create a copy of AppApiResponseFlowLine
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppApiResponseFlowLineImplCopyWith<_$AppApiResponseFlowLineImpl>
      get copyWith => throw _privateConstructorUsedError;
}

FlowLineElement _$FlowLineElementFromJson(Map<String, dynamic> json) {
  return _FlowLineElement.fromJson(json);
}

/// @nodoc
mixin _$FlowLineElement {
  @JsonKey(name: "enabled")
  bool get enabled => throw _privateConstructorUsedError;
  @JsonKey(name: "type")
  String get type => throw _privateConstructorUsedError;
  @JsonKey(name: "provider")
  String get provider => throw _privateConstructorUsedError;
  @JsonKey(name: "endpoint")
  String? get endpoint => throw _privateConstructorUsedError;
  @JsonKey(name: "dns")
  String? get dns => throw _privateConstructorUsedError;
  @JsonKey(name: "scanner")
  bool? get scanner => throw _privateConstructorUsedError;
  @JsonKey(name: "scanner_type")
  String? get scannerType => throw _privateConstructorUsedError;
  @JsonKey(name: "scanner_timeout")
  int? get scannerTimeout => throw _privateConstructorUsedError;
  @JsonKey(name: "psiphon")
  bool? get psiphon => throw _privateConstructorUsedError;
  @JsonKey(name: "psiphon_country")
  String? get psiphonCountry => throw _privateConstructorUsedError;
  @JsonKey(name: "gool")
  bool? get gool => throw _privateConstructorUsedError;
  @JsonKey(name: "url")
  String? get url => throw _privateConstructorUsedError;

  /// Serializes this FlowLineElement to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FlowLineElement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FlowLineElementCopyWith<FlowLineElement> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FlowLineElementCopyWith<$Res> {
  factory $FlowLineElementCopyWith(
          FlowLineElement value, $Res Function(FlowLineElement) then) =
      _$FlowLineElementCopyWithImpl<$Res, FlowLineElement>;
  @useResult
  $Res call(
      {@JsonKey(name: "enabled") bool enabled,
      @JsonKey(name: "type") String type,
      @JsonKey(name: "provider") String provider,
      @JsonKey(name: "endpoint") String? endpoint,
      @JsonKey(name: "dns") String? dns,
      @JsonKey(name: "scanner") bool? scanner,
      @JsonKey(name: "scanner_type") String? scannerType,
      @JsonKey(name: "scanner_timeout") int? scannerTimeout,
      @JsonKey(name: "psiphon") bool? psiphon,
      @JsonKey(name: "psiphon_country") String? psiphonCountry,
      @JsonKey(name: "gool") bool? gool,
      @JsonKey(name: "url") String? url});
}

/// @nodoc
class _$FlowLineElementCopyWithImpl<$Res, $Val extends FlowLineElement>
    implements $FlowLineElementCopyWith<$Res> {
  _$FlowLineElementCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FlowLineElement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
    Object? type = null,
    Object? provider = null,
    Object? endpoint = freezed,
    Object? dns = freezed,
    Object? scanner = freezed,
    Object? scannerType = freezed,
    Object? scannerTimeout = freezed,
    Object? psiphon = freezed,
    Object? psiphonCountry = freezed,
    Object? gool = freezed,
    Object? url = freezed,
  }) {
    return _then(_value.copyWith(
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _value.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      endpoint: freezed == endpoint
          ? _value.endpoint
          : endpoint // ignore: cast_nullable_to_non_nullable
              as String?,
      dns: freezed == dns
          ? _value.dns
          : dns // ignore: cast_nullable_to_non_nullable
              as String?,
      scanner: freezed == scanner
          ? _value.scanner
          : scanner // ignore: cast_nullable_to_non_nullable
              as bool?,
      scannerType: freezed == scannerType
          ? _value.scannerType
          : scannerType // ignore: cast_nullable_to_non_nullable
              as String?,
      scannerTimeout: freezed == scannerTimeout
          ? _value.scannerTimeout
          : scannerTimeout // ignore: cast_nullable_to_non_nullable
              as int?,
      psiphon: freezed == psiphon
          ? _value.psiphon
          : psiphon // ignore: cast_nullable_to_non_nullable
              as bool?,
      psiphonCountry: freezed == psiphonCountry
          ? _value.psiphonCountry
          : psiphonCountry // ignore: cast_nullable_to_non_nullable
              as String?,
      gool: freezed == gool
          ? _value.gool
          : gool // ignore: cast_nullable_to_non_nullable
              as bool?,
      url: freezed == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FlowLineElementImplCopyWith<$Res>
    implements $FlowLineElementCopyWith<$Res> {
  factory _$$FlowLineElementImplCopyWith(_$FlowLineElementImpl value,
          $Res Function(_$FlowLineElementImpl) then) =
      __$$FlowLineElementImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: "enabled") bool enabled,
      @JsonKey(name: "type") String type,
      @JsonKey(name: "provider") String provider,
      @JsonKey(name: "endpoint") String? endpoint,
      @JsonKey(name: "dns") String? dns,
      @JsonKey(name: "scanner") bool? scanner,
      @JsonKey(name: "scanner_type") String? scannerType,
      @JsonKey(name: "scanner_timeout") int? scannerTimeout,
      @JsonKey(name: "psiphon") bool? psiphon,
      @JsonKey(name: "psiphon_country") String? psiphonCountry,
      @JsonKey(name: "gool") bool? gool,
      @JsonKey(name: "url") String? url});
}

/// @nodoc
class __$$FlowLineElementImplCopyWithImpl<$Res>
    extends _$FlowLineElementCopyWithImpl<$Res, _$FlowLineElementImpl>
    implements _$$FlowLineElementImplCopyWith<$Res> {
  __$$FlowLineElementImplCopyWithImpl(
      _$FlowLineElementImpl _value, $Res Function(_$FlowLineElementImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlowLineElement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
    Object? type = null,
    Object? provider = null,
    Object? endpoint = freezed,
    Object? dns = freezed,
    Object? scanner = freezed,
    Object? scannerType = freezed,
    Object? scannerTimeout = freezed,
    Object? psiphon = freezed,
    Object? psiphonCountry = freezed,
    Object? gool = freezed,
    Object? url = freezed,
  }) {
    return _then(_$FlowLineElementImpl(
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _value.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      endpoint: freezed == endpoint
          ? _value.endpoint
          : endpoint // ignore: cast_nullable_to_non_nullable
              as String?,
      dns: freezed == dns
          ? _value.dns
          : dns // ignore: cast_nullable_to_non_nullable
              as String?,
      scanner: freezed == scanner
          ? _value.scanner
          : scanner // ignore: cast_nullable_to_non_nullable
              as bool?,
      scannerType: freezed == scannerType
          ? _value.scannerType
          : scannerType // ignore: cast_nullable_to_non_nullable
              as String?,
      scannerTimeout: freezed == scannerTimeout
          ? _value.scannerTimeout
          : scannerTimeout // ignore: cast_nullable_to_non_nullable
              as int?,
      psiphon: freezed == psiphon
          ? _value.psiphon
          : psiphon // ignore: cast_nullable_to_non_nullable
              as bool?,
      psiphonCountry: freezed == psiphonCountry
          ? _value.psiphonCountry
          : psiphonCountry // ignore: cast_nullable_to_non_nullable
              as String?,
      gool: freezed == gool
          ? _value.gool
          : gool // ignore: cast_nullable_to_non_nullable
              as bool?,
      url: freezed == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FlowLineElementImpl implements _FlowLineElement {
  const _$FlowLineElementImpl(
      {@JsonKey(name: "enabled") required this.enabled,
      @JsonKey(name: "type") required this.type,
      @JsonKey(name: "provider") required this.provider,
      @JsonKey(name: "endpoint") this.endpoint,
      @JsonKey(name: "dns") this.dns,
      @JsonKey(name: "scanner") this.scanner,
      @JsonKey(name: "scanner_type") this.scannerType,
      @JsonKey(name: "scanner_timeout") this.scannerTimeout,
      @JsonKey(name: "psiphon") this.psiphon,
      @JsonKey(name: "psiphon_country") this.psiphonCountry,
      @JsonKey(name: "gool") this.gool,
      @JsonKey(name: "url") this.url});

  factory _$FlowLineElementImpl.fromJson(Map<String, dynamic> json) =>
      _$$FlowLineElementImplFromJson(json);

  @override
  @JsonKey(name: "enabled")
  final bool enabled;
  @override
  @JsonKey(name: "type")
  final String type;
  @override
  @JsonKey(name: "provider")
  final String provider;
  @override
  @JsonKey(name: "endpoint")
  final String? endpoint;
  @override
  @JsonKey(name: "dns")
  final String? dns;
  @override
  @JsonKey(name: "scanner")
  final bool? scanner;
  @override
  @JsonKey(name: "scanner_type")
  final String? scannerType;
  @override
  @JsonKey(name: "scanner_timeout")
  final int? scannerTimeout;
  @override
  @JsonKey(name: "psiphon")
  final bool? psiphon;
  @override
  @JsonKey(name: "psiphon_country")
  final String? psiphonCountry;
  @override
  @JsonKey(name: "gool")
  final bool? gool;
  @override
  @JsonKey(name: "url")
  final String? url;

  @override
  String toString() {
    return 'FlowLineElement(enabled: $enabled, type: $type, provider: $provider, endpoint: $endpoint, dns: $dns, scanner: $scanner, scannerType: $scannerType, scannerTimeout: $scannerTimeout, psiphon: $psiphon, psiphonCountry: $psiphonCountry, gool: $gool, url: $url)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlowLineElementImpl &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.endpoint, endpoint) ||
                other.endpoint == endpoint) &&
            (identical(other.dns, dns) || other.dns == dns) &&
            (identical(other.scanner, scanner) || other.scanner == scanner) &&
            (identical(other.scannerType, scannerType) ||
                other.scannerType == scannerType) &&
            (identical(other.scannerTimeout, scannerTimeout) ||
                other.scannerTimeout == scannerTimeout) &&
            (identical(other.psiphon, psiphon) || other.psiphon == psiphon) &&
            (identical(other.psiphonCountry, psiphonCountry) ||
                other.psiphonCountry == psiphonCountry) &&
            (identical(other.gool, gool) || other.gool == gool) &&
            (identical(other.url, url) || other.url == url));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      enabled,
      type,
      provider,
      endpoint,
      dns,
      scanner,
      scannerType,
      scannerTimeout,
      psiphon,
      psiphonCountry,
      gool,
      url);

  /// Create a copy of FlowLineElement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlowLineElementImplCopyWith<_$FlowLineElementImpl> get copyWith =>
      __$$FlowLineElementImplCopyWithImpl<_$FlowLineElementImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FlowLineElementImplToJson(
      this,
    );
  }
}

abstract class _FlowLineElement implements FlowLineElement {
  const factory _FlowLineElement(
      {@JsonKey(name: "enabled") required final bool enabled,
      @JsonKey(name: "type") required final String type,
      @JsonKey(name: "provider") required final String provider,
      @JsonKey(name: "endpoint") final String? endpoint,
      @JsonKey(name: "dns") final String? dns,
      @JsonKey(name: "scanner") final bool? scanner,
      @JsonKey(name: "scanner_type") final String? scannerType,
      @JsonKey(name: "scanner_timeout") final int? scannerTimeout,
      @JsonKey(name: "psiphon") final bool? psiphon,
      @JsonKey(name: "psiphon_country") final String? psiphonCountry,
      @JsonKey(name: "gool") final bool? gool,
      @JsonKey(name: "url") final String? url}) = _$FlowLineElementImpl;

  factory _FlowLineElement.fromJson(Map<String, dynamic> json) =
      _$FlowLineElementImpl.fromJson;

  @override
  @JsonKey(name: "enabled")
  bool get enabled;
  @override
  @JsonKey(name: "type")
  String get type;
  @override
  @JsonKey(name: "provider")
  String get provider;
  @override
  @JsonKey(name: "endpoint")
  String? get endpoint;
  @override
  @JsonKey(name: "dns")
  String? get dns;
  @override
  @JsonKey(name: "scanner")
  bool? get scanner;
  @override
  @JsonKey(name: "scanner_type")
  String? get scannerType;
  @override
  @JsonKey(name: "scanner_timeout")
  int? get scannerTimeout;
  @override
  @JsonKey(name: "psiphon")
  bool? get psiphon;
  @override
  @JsonKey(name: "psiphon_country")
  String? get psiphonCountry;
  @override
  @JsonKey(name: "gool")
  bool? get gool;
  @override
  @JsonKey(name: "url")
  String? get url;

  /// Create a copy of FlowLineElement
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlowLineElementImplCopyWith<_$FlowLineElementImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Version _$VersionFromJson(Map<String, dynamic> json) {
  return _Version.fromJson(json);
}

/// @nodoc
mixin _$Version {
  @JsonKey(name: "github")
  String get github => throw _privateConstructorUsedError;
  @JsonKey(name: "testFlight")
  String get testFlight => throw _privateConstructorUsedError;
  @JsonKey(name: "appleStore")
  String get appleStore => throw _privateConstructorUsedError;
  @JsonKey(name: "googlePlay")
  String get googlePlay => throw _privateConstructorUsedError;
  @JsonKey(name: "microsoftStore")
  String get microsoftStore => throw _privateConstructorUsedError;

  /// Serializes this Version to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Version
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VersionCopyWith<Version> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VersionCopyWith<$Res> {
  factory $VersionCopyWith(Version value, $Res Function(Version) then) =
      _$VersionCopyWithImpl<$Res, Version>;
  @useResult
  $Res call(
      {@JsonKey(name: "github") String github,
      @JsonKey(name: "testFlight") String testFlight,
      @JsonKey(name: "appleStore") String appleStore,
      @JsonKey(name: "googlePlay") String googlePlay,
      @JsonKey(name: "microsoftStore") String microsoftStore});
}

/// @nodoc
class _$VersionCopyWithImpl<$Res, $Val extends Version>
    implements $VersionCopyWith<$Res> {
  _$VersionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Version
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? github = null,
    Object? testFlight = null,
    Object? appleStore = null,
    Object? googlePlay = null,
    Object? microsoftStore = null,
  }) {
    return _then(_value.copyWith(
      github: null == github
          ? _value.github
          : github // ignore: cast_nullable_to_non_nullable
              as String,
      testFlight: null == testFlight
          ? _value.testFlight
          : testFlight // ignore: cast_nullable_to_non_nullable
              as String,
      appleStore: null == appleStore
          ? _value.appleStore
          : appleStore // ignore: cast_nullable_to_non_nullable
              as String,
      googlePlay: null == googlePlay
          ? _value.googlePlay
          : googlePlay // ignore: cast_nullable_to_non_nullable
              as String,
      microsoftStore: null == microsoftStore
          ? _value.microsoftStore
          : microsoftStore // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VersionImplCopyWith<$Res> implements $VersionCopyWith<$Res> {
  factory _$$VersionImplCopyWith(
          _$VersionImpl value, $Res Function(_$VersionImpl) then) =
      __$$VersionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: "github") String github,
      @JsonKey(name: "testFlight") String testFlight,
      @JsonKey(name: "appleStore") String appleStore,
      @JsonKey(name: "googlePlay") String googlePlay,
      @JsonKey(name: "microsoftStore") String microsoftStore});
}

/// @nodoc
class __$$VersionImplCopyWithImpl<$Res>
    extends _$VersionCopyWithImpl<$Res, _$VersionImpl>
    implements _$$VersionImplCopyWith<$Res> {
  __$$VersionImplCopyWithImpl(
      _$VersionImpl _value, $Res Function(_$VersionImpl) _then)
      : super(_value, _then);

  /// Create a copy of Version
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? github = null,
    Object? testFlight = null,
    Object? appleStore = null,
    Object? googlePlay = null,
    Object? microsoftStore = null,
  }) {
    return _then(_$VersionImpl(
      github: null == github
          ? _value.github
          : github // ignore: cast_nullable_to_non_nullable
              as String,
      testFlight: null == testFlight
          ? _value.testFlight
          : testFlight // ignore: cast_nullable_to_non_nullable
              as String,
      appleStore: null == appleStore
          ? _value.appleStore
          : appleStore // ignore: cast_nullable_to_non_nullable
              as String,
      googlePlay: null == googlePlay
          ? _value.googlePlay
          : googlePlay // ignore: cast_nullable_to_non_nullable
              as String,
      microsoftStore: null == microsoftStore
          ? _value.microsoftStore
          : microsoftStore // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VersionImpl implements _Version {
  const _$VersionImpl(
      {@JsonKey(name: "github") required this.github,
      @JsonKey(name: "testFlight") required this.testFlight,
      @JsonKey(name: "appleStore") required this.appleStore,
      @JsonKey(name: "googlePlay") required this.googlePlay,
      @JsonKey(name: "microsoftStore") required this.microsoftStore});

  factory _$VersionImpl.fromJson(Map<String, dynamic> json) =>
      _$$VersionImplFromJson(json);

  @override
  @JsonKey(name: "github")
  final String github;
  @override
  @JsonKey(name: "testFlight")
  final String testFlight;
  @override
  @JsonKey(name: "appleStore")
  final String appleStore;
  @override
  @JsonKey(name: "googlePlay")
  final String googlePlay;
  @override
  @JsonKey(name: "microsoftStore")
  final String microsoftStore;

  @override
  String toString() {
    return 'Version(github: $github, testFlight: $testFlight, appleStore: $appleStore, googlePlay: $googlePlay, microsoftStore: $microsoftStore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VersionImpl &&
            (identical(other.github, github) || other.github == github) &&
            (identical(other.testFlight, testFlight) ||
                other.testFlight == testFlight) &&
            (identical(other.appleStore, appleStore) ||
                other.appleStore == appleStore) &&
            (identical(other.googlePlay, googlePlay) ||
                other.googlePlay == googlePlay) &&
            (identical(other.microsoftStore, microsoftStore) ||
                other.microsoftStore == microsoftStore));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, github, testFlight, appleStore, googlePlay, microsoftStore);

  /// Create a copy of Version
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VersionImplCopyWith<_$VersionImpl> get copyWith =>
      __$$VersionImplCopyWithImpl<_$VersionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VersionImplToJson(
      this,
    );
  }
}

abstract class _Version implements Version {
  const factory _Version(
      {@JsonKey(name: "github") required final String github,
      @JsonKey(name: "testFlight") required final String testFlight,
      @JsonKey(name: "appleStore") required final String appleStore,
      @JsonKey(name: "googlePlay") required final String googlePlay,
      @JsonKey(name: "microsoftStore")
      required final String microsoftStore}) = _$VersionImpl;

  factory _Version.fromJson(Map<String, dynamic> json) = _$VersionImpl.fromJson;

  @override
  @JsonKey(name: "github")
  String get github;
  @override
  @JsonKey(name: "testFlight")
  String get testFlight;
  @override
  @JsonKey(name: "appleStore")
  String get appleStore;
  @override
  @JsonKey(name: "googlePlay")
  String get googlePlay;
  @override
  @JsonKey(name: "microsoftStore")
  String get microsoftStore;

  /// Create a copy of Version
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VersionImplCopyWith<_$VersionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
