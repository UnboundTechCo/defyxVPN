// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_api_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppApiResponse {

@JsonKey(name: "version") Version get version;@JsonKey(name: "forceUpdate") Map<String, bool> get forceUpdate;@JsonKey(name: "changeLog") Map<String, List<String>> get changeLog;@JsonKey(name: "flowLine") AppApiResponseFlowLine get flowLine;@JsonKey(name: "testUrls") List<String> get testUrls;
/// Create a copy of AppApiResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppApiResponseCopyWith<AppApiResponse> get copyWith => _$AppApiResponseCopyWithImpl<AppApiResponse>(this as AppApiResponse, _$identity);

  /// Serializes this AppApiResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppApiResponse&&(identical(other.version, version) || other.version == version)&&const DeepCollectionEquality().equals(other.forceUpdate, forceUpdate)&&const DeepCollectionEquality().equals(other.changeLog, changeLog)&&(identical(other.flowLine, flowLine) || other.flowLine == flowLine)&&const DeepCollectionEquality().equals(other.testUrls, testUrls));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,const DeepCollectionEquality().hash(forceUpdate),const DeepCollectionEquality().hash(changeLog),flowLine,const DeepCollectionEquality().hash(testUrls));

@override
String toString() {
  return 'AppApiResponse(version: $version, forceUpdate: $forceUpdate, changeLog: $changeLog, flowLine: $flowLine, testUrls: $testUrls)';
}


}

/// @nodoc
abstract mixin class $AppApiResponseCopyWith<$Res>  {
  factory $AppApiResponseCopyWith(AppApiResponse value, $Res Function(AppApiResponse) _then) = _$AppApiResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "version") Version version,@JsonKey(name: "forceUpdate") Map<String, bool> forceUpdate,@JsonKey(name: "changeLog") Map<String, List<String>> changeLog,@JsonKey(name: "flowLine") AppApiResponseFlowLine flowLine,@JsonKey(name: "testUrls") List<String> testUrls
});


$VersionCopyWith<$Res> get version;$AppApiResponseFlowLineCopyWith<$Res> get flowLine;

}
/// @nodoc
class _$AppApiResponseCopyWithImpl<$Res>
    implements $AppApiResponseCopyWith<$Res> {
  _$AppApiResponseCopyWithImpl(this._self, this._then);

  final AppApiResponse _self;
  final $Res Function(AppApiResponse) _then;

/// Create a copy of AppApiResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? forceUpdate = null,Object? changeLog = null,Object? flowLine = null,Object? testUrls = null,}) {
  return _then(_self.copyWith(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as Version,forceUpdate: null == forceUpdate ? _self.forceUpdate : forceUpdate // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,changeLog: null == changeLog ? _self.changeLog : changeLog // ignore: cast_nullable_to_non_nullable
as Map<String, List<String>>,flowLine: null == flowLine ? _self.flowLine : flowLine // ignore: cast_nullable_to_non_nullable
as AppApiResponseFlowLine,testUrls: null == testUrls ? _self.testUrls : testUrls // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of AppApiResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VersionCopyWith<$Res> get version {
  
  return $VersionCopyWith<$Res>(_self.version, (value) {
    return _then(_self.copyWith(version: value));
  });
}/// Create a copy of AppApiResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AppApiResponseFlowLineCopyWith<$Res> get flowLine {
  
  return $AppApiResponseFlowLineCopyWith<$Res>(_self.flowLine, (value) {
    return _then(_self.copyWith(flowLine: value));
  });
}
}


/// Adds pattern-matching-related methods to [AppApiResponse].
extension AppApiResponsePatterns on AppApiResponse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppApiResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppApiResponse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppApiResponse value)  $default,){
final _that = this;
switch (_that) {
case _AppApiResponse():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppApiResponse value)?  $default,){
final _that = this;
switch (_that) {
case _AppApiResponse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: "version")  Version version, @JsonKey(name: "forceUpdate")  Map<String, bool> forceUpdate, @JsonKey(name: "changeLog")  Map<String, List<String>> changeLog, @JsonKey(name: "flowLine")  AppApiResponseFlowLine flowLine, @JsonKey(name: "testUrls")  List<String> testUrls)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppApiResponse() when $default != null:
return $default(_that.version,_that.forceUpdate,_that.changeLog,_that.flowLine,_that.testUrls);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: "version")  Version version, @JsonKey(name: "forceUpdate")  Map<String, bool> forceUpdate, @JsonKey(name: "changeLog")  Map<String, List<String>> changeLog, @JsonKey(name: "flowLine")  AppApiResponseFlowLine flowLine, @JsonKey(name: "testUrls")  List<String> testUrls)  $default,) {final _that = this;
switch (_that) {
case _AppApiResponse():
return $default(_that.version,_that.forceUpdate,_that.changeLog,_that.flowLine,_that.testUrls);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: "version")  Version version, @JsonKey(name: "forceUpdate")  Map<String, bool> forceUpdate, @JsonKey(name: "changeLog")  Map<String, List<String>> changeLog, @JsonKey(name: "flowLine")  AppApiResponseFlowLine flowLine, @JsonKey(name: "testUrls")  List<String> testUrls)?  $default,) {final _that = this;
switch (_that) {
case _AppApiResponse() when $default != null:
return $default(_that.version,_that.forceUpdate,_that.changeLog,_that.flowLine,_that.testUrls);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppApiResponse implements AppApiResponse {
  const _AppApiResponse({@JsonKey(name: "version") required this.version, @JsonKey(name: "forceUpdate") required final  Map<String, bool> forceUpdate, @JsonKey(name: "changeLog") required final  Map<String, List<String>> changeLog, @JsonKey(name: "flowLine") required this.flowLine, @JsonKey(name: "testUrls") required final  List<String> testUrls}): _forceUpdate = forceUpdate,_changeLog = changeLog,_testUrls = testUrls;
  factory _AppApiResponse.fromJson(Map<String, dynamic> json) => _$AppApiResponseFromJson(json);

@override@JsonKey(name: "version") final  Version version;
 final  Map<String, bool> _forceUpdate;
@override@JsonKey(name: "forceUpdate") Map<String, bool> get forceUpdate {
  if (_forceUpdate is EqualUnmodifiableMapView) return _forceUpdate;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_forceUpdate);
}

 final  Map<String, List<String>> _changeLog;
@override@JsonKey(name: "changeLog") Map<String, List<String>> get changeLog {
  if (_changeLog is EqualUnmodifiableMapView) return _changeLog;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_changeLog);
}

@override@JsonKey(name: "flowLine") final  AppApiResponseFlowLine flowLine;
 final  List<String> _testUrls;
@override@JsonKey(name: "testUrls") List<String> get testUrls {
  if (_testUrls is EqualUnmodifiableListView) return _testUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_testUrls);
}


/// Create a copy of AppApiResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppApiResponseCopyWith<_AppApiResponse> get copyWith => __$AppApiResponseCopyWithImpl<_AppApiResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppApiResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppApiResponse&&(identical(other.version, version) || other.version == version)&&const DeepCollectionEquality().equals(other._forceUpdate, _forceUpdate)&&const DeepCollectionEquality().equals(other._changeLog, _changeLog)&&(identical(other.flowLine, flowLine) || other.flowLine == flowLine)&&const DeepCollectionEquality().equals(other._testUrls, _testUrls));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,const DeepCollectionEquality().hash(_forceUpdate),const DeepCollectionEquality().hash(_changeLog),flowLine,const DeepCollectionEquality().hash(_testUrls));

@override
String toString() {
  return 'AppApiResponse(version: $version, forceUpdate: $forceUpdate, changeLog: $changeLog, flowLine: $flowLine, testUrls: $testUrls)';
}


}

/// @nodoc
abstract mixin class _$AppApiResponseCopyWith<$Res> implements $AppApiResponseCopyWith<$Res> {
  factory _$AppApiResponseCopyWith(_AppApiResponse value, $Res Function(_AppApiResponse) _then) = __$AppApiResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: "version") Version version,@JsonKey(name: "forceUpdate") Map<String, bool> forceUpdate,@JsonKey(name: "changeLog") Map<String, List<String>> changeLog,@JsonKey(name: "flowLine") AppApiResponseFlowLine flowLine,@JsonKey(name: "testUrls") List<String> testUrls
});


@override $VersionCopyWith<$Res> get version;@override $AppApiResponseFlowLineCopyWith<$Res> get flowLine;

}
/// @nodoc
class __$AppApiResponseCopyWithImpl<$Res>
    implements _$AppApiResponseCopyWith<$Res> {
  __$AppApiResponseCopyWithImpl(this._self, this._then);

  final _AppApiResponse _self;
  final $Res Function(_AppApiResponse) _then;

/// Create a copy of AppApiResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? forceUpdate = null,Object? changeLog = null,Object? flowLine = null,Object? testUrls = null,}) {
  return _then(_AppApiResponse(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as Version,forceUpdate: null == forceUpdate ? _self._forceUpdate : forceUpdate // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,changeLog: null == changeLog ? _self._changeLog : changeLog // ignore: cast_nullable_to_non_nullable
as Map<String, List<String>>,flowLine: null == flowLine ? _self.flowLine : flowLine // ignore: cast_nullable_to_non_nullable
as AppApiResponseFlowLine,testUrls: null == testUrls ? _self._testUrls : testUrls // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of AppApiResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VersionCopyWith<$Res> get version {
  
  return $VersionCopyWith<$Res>(_self.version, (value) {
    return _then(_self.copyWith(version: value));
  });
}/// Create a copy of AppApiResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AppApiResponseFlowLineCopyWith<$Res> get flowLine {
  
  return $AppApiResponseFlowLineCopyWith<$Res>(_self.flowLine, (value) {
    return _then(_self.copyWith(flowLine: value));
  });
}
}


/// @nodoc
mixin _$AppApiResponseFlowLine {

@JsonKey(name: "startLine") int get startLine;@JsonKey(name: "flowLine") List<FlowLineElement> get flowLine;
/// Create a copy of AppApiResponseFlowLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppApiResponseFlowLineCopyWith<AppApiResponseFlowLine> get copyWith => _$AppApiResponseFlowLineCopyWithImpl<AppApiResponseFlowLine>(this as AppApiResponseFlowLine, _$identity);

  /// Serializes this AppApiResponseFlowLine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppApiResponseFlowLine&&(identical(other.startLine, startLine) || other.startLine == startLine)&&const DeepCollectionEquality().equals(other.flowLine, flowLine));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,startLine,const DeepCollectionEquality().hash(flowLine));

@override
String toString() {
  return 'AppApiResponseFlowLine(startLine: $startLine, flowLine: $flowLine)';
}


}

/// @nodoc
abstract mixin class $AppApiResponseFlowLineCopyWith<$Res>  {
  factory $AppApiResponseFlowLineCopyWith(AppApiResponseFlowLine value, $Res Function(AppApiResponseFlowLine) _then) = _$AppApiResponseFlowLineCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "startLine") int startLine,@JsonKey(name: "flowLine") List<FlowLineElement> flowLine
});




}
/// @nodoc
class _$AppApiResponseFlowLineCopyWithImpl<$Res>
    implements $AppApiResponseFlowLineCopyWith<$Res> {
  _$AppApiResponseFlowLineCopyWithImpl(this._self, this._then);

  final AppApiResponseFlowLine _self;
  final $Res Function(AppApiResponseFlowLine) _then;

/// Create a copy of AppApiResponseFlowLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startLine = null,Object? flowLine = null,}) {
  return _then(_self.copyWith(
startLine: null == startLine ? _self.startLine : startLine // ignore: cast_nullable_to_non_nullable
as int,flowLine: null == flowLine ? _self.flowLine : flowLine // ignore: cast_nullable_to_non_nullable
as List<FlowLineElement>,
  ));
}

}


/// Adds pattern-matching-related methods to [AppApiResponseFlowLine].
extension AppApiResponseFlowLinePatterns on AppApiResponseFlowLine {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppApiResponseFlowLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppApiResponseFlowLine() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppApiResponseFlowLine value)  $default,){
final _that = this;
switch (_that) {
case _AppApiResponseFlowLine():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppApiResponseFlowLine value)?  $default,){
final _that = this;
switch (_that) {
case _AppApiResponseFlowLine() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: "startLine")  int startLine, @JsonKey(name: "flowLine")  List<FlowLineElement> flowLine)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppApiResponseFlowLine() when $default != null:
return $default(_that.startLine,_that.flowLine);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: "startLine")  int startLine, @JsonKey(name: "flowLine")  List<FlowLineElement> flowLine)  $default,) {final _that = this;
switch (_that) {
case _AppApiResponseFlowLine():
return $default(_that.startLine,_that.flowLine);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: "startLine")  int startLine, @JsonKey(name: "flowLine")  List<FlowLineElement> flowLine)?  $default,) {final _that = this;
switch (_that) {
case _AppApiResponseFlowLine() when $default != null:
return $default(_that.startLine,_that.flowLine);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppApiResponseFlowLine implements AppApiResponseFlowLine {
  const _AppApiResponseFlowLine({@JsonKey(name: "startLine") required this.startLine, @JsonKey(name: "flowLine") required final  List<FlowLineElement> flowLine}): _flowLine = flowLine;
  factory _AppApiResponseFlowLine.fromJson(Map<String, dynamic> json) => _$AppApiResponseFlowLineFromJson(json);

@override@JsonKey(name: "startLine") final  int startLine;
 final  List<FlowLineElement> _flowLine;
@override@JsonKey(name: "flowLine") List<FlowLineElement> get flowLine {
  if (_flowLine is EqualUnmodifiableListView) return _flowLine;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_flowLine);
}


/// Create a copy of AppApiResponseFlowLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppApiResponseFlowLineCopyWith<_AppApiResponseFlowLine> get copyWith => __$AppApiResponseFlowLineCopyWithImpl<_AppApiResponseFlowLine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppApiResponseFlowLineToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppApiResponseFlowLine&&(identical(other.startLine, startLine) || other.startLine == startLine)&&const DeepCollectionEquality().equals(other._flowLine, _flowLine));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,startLine,const DeepCollectionEquality().hash(_flowLine));

@override
String toString() {
  return 'AppApiResponseFlowLine(startLine: $startLine, flowLine: $flowLine)';
}


}

/// @nodoc
abstract mixin class _$AppApiResponseFlowLineCopyWith<$Res> implements $AppApiResponseFlowLineCopyWith<$Res> {
  factory _$AppApiResponseFlowLineCopyWith(_AppApiResponseFlowLine value, $Res Function(_AppApiResponseFlowLine) _then) = __$AppApiResponseFlowLineCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: "startLine") int startLine,@JsonKey(name: "flowLine") List<FlowLineElement> flowLine
});




}
/// @nodoc
class __$AppApiResponseFlowLineCopyWithImpl<$Res>
    implements _$AppApiResponseFlowLineCopyWith<$Res> {
  __$AppApiResponseFlowLineCopyWithImpl(this._self, this._then);

  final _AppApiResponseFlowLine _self;
  final $Res Function(_AppApiResponseFlowLine) _then;

/// Create a copy of AppApiResponseFlowLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startLine = null,Object? flowLine = null,}) {
  return _then(_AppApiResponseFlowLine(
startLine: null == startLine ? _self.startLine : startLine // ignore: cast_nullable_to_non_nullable
as int,flowLine: null == flowLine ? _self._flowLine : flowLine // ignore: cast_nullable_to_non_nullable
as List<FlowLineElement>,
  ));
}


}


/// @nodoc
mixin _$FlowLineElement {

@JsonKey(name: "enabled") bool get enabled;@JsonKey(name: "type") String get type;@JsonKey(name: "provider") String get provider;@JsonKey(name: "endpoint") String? get endpoint;@JsonKey(name: "dns") String? get dns;@JsonKey(name: "scanner") bool? get scanner;@JsonKey(name: "scanner_type") String? get scannerType;@JsonKey(name: "scanner_timeout") int? get scannerTimeout;@JsonKey(name: "psiphon") bool? get psiphon;@JsonKey(name: "psiphon_country") String? get psiphonCountry;@JsonKey(name: "gool") bool? get gool;@JsonKey(name: "url") String? get url;
/// Create a copy of FlowLineElement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FlowLineElementCopyWith<FlowLineElement> get copyWith => _$FlowLineElementCopyWithImpl<FlowLineElement>(this as FlowLineElement, _$identity);

  /// Serializes this FlowLineElement to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FlowLineElement&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.type, type) || other.type == type)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.endpoint, endpoint) || other.endpoint == endpoint)&&(identical(other.dns, dns) || other.dns == dns)&&(identical(other.scanner, scanner) || other.scanner == scanner)&&(identical(other.scannerType, scannerType) || other.scannerType == scannerType)&&(identical(other.scannerTimeout, scannerTimeout) || other.scannerTimeout == scannerTimeout)&&(identical(other.psiphon, psiphon) || other.psiphon == psiphon)&&(identical(other.psiphonCountry, psiphonCountry) || other.psiphonCountry == psiphonCountry)&&(identical(other.gool, gool) || other.gool == gool)&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,type,provider,endpoint,dns,scanner,scannerType,scannerTimeout,psiphon,psiphonCountry,gool,url);

@override
String toString() {
  return 'FlowLineElement(enabled: $enabled, type: $type, provider: $provider, endpoint: $endpoint, dns: $dns, scanner: $scanner, scannerType: $scannerType, scannerTimeout: $scannerTimeout, psiphon: $psiphon, psiphonCountry: $psiphonCountry, gool: $gool, url: $url)';
}


}

/// @nodoc
abstract mixin class $FlowLineElementCopyWith<$Res>  {
  factory $FlowLineElementCopyWith(FlowLineElement value, $Res Function(FlowLineElement) _then) = _$FlowLineElementCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "enabled") bool enabled,@JsonKey(name: "type") String type,@JsonKey(name: "provider") String provider,@JsonKey(name: "endpoint") String? endpoint,@JsonKey(name: "dns") String? dns,@JsonKey(name: "scanner") bool? scanner,@JsonKey(name: "scanner_type") String? scannerType,@JsonKey(name: "scanner_timeout") int? scannerTimeout,@JsonKey(name: "psiphon") bool? psiphon,@JsonKey(name: "psiphon_country") String? psiphonCountry,@JsonKey(name: "gool") bool? gool,@JsonKey(name: "url") String? url
});




}
/// @nodoc
class _$FlowLineElementCopyWithImpl<$Res>
    implements $FlowLineElementCopyWith<$Res> {
  _$FlowLineElementCopyWithImpl(this._self, this._then);

  final FlowLineElement _self;
  final $Res Function(FlowLineElement) _then;

/// Create a copy of FlowLineElement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? type = null,Object? provider = null,Object? endpoint = freezed,Object? dns = freezed,Object? scanner = freezed,Object? scannerType = freezed,Object? scannerTimeout = freezed,Object? psiphon = freezed,Object? psiphonCountry = freezed,Object? gool = freezed,Object? url = freezed,}) {
  return _then(_self.copyWith(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,endpoint: freezed == endpoint ? _self.endpoint : endpoint // ignore: cast_nullable_to_non_nullable
as String?,dns: freezed == dns ? _self.dns : dns // ignore: cast_nullable_to_non_nullable
as String?,scanner: freezed == scanner ? _self.scanner : scanner // ignore: cast_nullable_to_non_nullable
as bool?,scannerType: freezed == scannerType ? _self.scannerType : scannerType // ignore: cast_nullable_to_non_nullable
as String?,scannerTimeout: freezed == scannerTimeout ? _self.scannerTimeout : scannerTimeout // ignore: cast_nullable_to_non_nullable
as int?,psiphon: freezed == psiphon ? _self.psiphon : psiphon // ignore: cast_nullable_to_non_nullable
as bool?,psiphonCountry: freezed == psiphonCountry ? _self.psiphonCountry : psiphonCountry // ignore: cast_nullable_to_non_nullable
as String?,gool: freezed == gool ? _self.gool : gool // ignore: cast_nullable_to_non_nullable
as bool?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FlowLineElement].
extension FlowLineElementPatterns on FlowLineElement {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FlowLineElement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FlowLineElement() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FlowLineElement value)  $default,){
final _that = this;
switch (_that) {
case _FlowLineElement():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FlowLineElement value)?  $default,){
final _that = this;
switch (_that) {
case _FlowLineElement() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: "enabled")  bool enabled, @JsonKey(name: "type")  String type, @JsonKey(name: "provider")  String provider, @JsonKey(name: "endpoint")  String? endpoint, @JsonKey(name: "dns")  String? dns, @JsonKey(name: "scanner")  bool? scanner, @JsonKey(name: "scanner_type")  String? scannerType, @JsonKey(name: "scanner_timeout")  int? scannerTimeout, @JsonKey(name: "psiphon")  bool? psiphon, @JsonKey(name: "psiphon_country")  String? psiphonCountry, @JsonKey(name: "gool")  bool? gool, @JsonKey(name: "url")  String? url)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FlowLineElement() when $default != null:
return $default(_that.enabled,_that.type,_that.provider,_that.endpoint,_that.dns,_that.scanner,_that.scannerType,_that.scannerTimeout,_that.psiphon,_that.psiphonCountry,_that.gool,_that.url);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: "enabled")  bool enabled, @JsonKey(name: "type")  String type, @JsonKey(name: "provider")  String provider, @JsonKey(name: "endpoint")  String? endpoint, @JsonKey(name: "dns")  String? dns, @JsonKey(name: "scanner")  bool? scanner, @JsonKey(name: "scanner_type")  String? scannerType, @JsonKey(name: "scanner_timeout")  int? scannerTimeout, @JsonKey(name: "psiphon")  bool? psiphon, @JsonKey(name: "psiphon_country")  String? psiphonCountry, @JsonKey(name: "gool")  bool? gool, @JsonKey(name: "url")  String? url)  $default,) {final _that = this;
switch (_that) {
case _FlowLineElement():
return $default(_that.enabled,_that.type,_that.provider,_that.endpoint,_that.dns,_that.scanner,_that.scannerType,_that.scannerTimeout,_that.psiphon,_that.psiphonCountry,_that.gool,_that.url);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: "enabled")  bool enabled, @JsonKey(name: "type")  String type, @JsonKey(name: "provider")  String provider, @JsonKey(name: "endpoint")  String? endpoint, @JsonKey(name: "dns")  String? dns, @JsonKey(name: "scanner")  bool? scanner, @JsonKey(name: "scanner_type")  String? scannerType, @JsonKey(name: "scanner_timeout")  int? scannerTimeout, @JsonKey(name: "psiphon")  bool? psiphon, @JsonKey(name: "psiphon_country")  String? psiphonCountry, @JsonKey(name: "gool")  bool? gool, @JsonKey(name: "url")  String? url)?  $default,) {final _that = this;
switch (_that) {
case _FlowLineElement() when $default != null:
return $default(_that.enabled,_that.type,_that.provider,_that.endpoint,_that.dns,_that.scanner,_that.scannerType,_that.scannerTimeout,_that.psiphon,_that.psiphonCountry,_that.gool,_that.url);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FlowLineElement implements FlowLineElement {
  const _FlowLineElement({@JsonKey(name: "enabled") required this.enabled, @JsonKey(name: "type") required this.type, @JsonKey(name: "provider") required this.provider, @JsonKey(name: "endpoint") this.endpoint, @JsonKey(name: "dns") this.dns, @JsonKey(name: "scanner") this.scanner, @JsonKey(name: "scanner_type") this.scannerType, @JsonKey(name: "scanner_timeout") this.scannerTimeout, @JsonKey(name: "psiphon") this.psiphon, @JsonKey(name: "psiphon_country") this.psiphonCountry, @JsonKey(name: "gool") this.gool, @JsonKey(name: "url") this.url});
  factory _FlowLineElement.fromJson(Map<String, dynamic> json) => _$FlowLineElementFromJson(json);

@override@JsonKey(name: "enabled") final  bool enabled;
@override@JsonKey(name: "type") final  String type;
@override@JsonKey(name: "provider") final  String provider;
@override@JsonKey(name: "endpoint") final  String? endpoint;
@override@JsonKey(name: "dns") final  String? dns;
@override@JsonKey(name: "scanner") final  bool? scanner;
@override@JsonKey(name: "scanner_type") final  String? scannerType;
@override@JsonKey(name: "scanner_timeout") final  int? scannerTimeout;
@override@JsonKey(name: "psiphon") final  bool? psiphon;
@override@JsonKey(name: "psiphon_country") final  String? psiphonCountry;
@override@JsonKey(name: "gool") final  bool? gool;
@override@JsonKey(name: "url") final  String? url;

/// Create a copy of FlowLineElement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FlowLineElementCopyWith<_FlowLineElement> get copyWith => __$FlowLineElementCopyWithImpl<_FlowLineElement>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FlowLineElementToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FlowLineElement&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.type, type) || other.type == type)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.endpoint, endpoint) || other.endpoint == endpoint)&&(identical(other.dns, dns) || other.dns == dns)&&(identical(other.scanner, scanner) || other.scanner == scanner)&&(identical(other.scannerType, scannerType) || other.scannerType == scannerType)&&(identical(other.scannerTimeout, scannerTimeout) || other.scannerTimeout == scannerTimeout)&&(identical(other.psiphon, psiphon) || other.psiphon == psiphon)&&(identical(other.psiphonCountry, psiphonCountry) || other.psiphonCountry == psiphonCountry)&&(identical(other.gool, gool) || other.gool == gool)&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,type,provider,endpoint,dns,scanner,scannerType,scannerTimeout,psiphon,psiphonCountry,gool,url);

@override
String toString() {
  return 'FlowLineElement(enabled: $enabled, type: $type, provider: $provider, endpoint: $endpoint, dns: $dns, scanner: $scanner, scannerType: $scannerType, scannerTimeout: $scannerTimeout, psiphon: $psiphon, psiphonCountry: $psiphonCountry, gool: $gool, url: $url)';
}


}

/// @nodoc
abstract mixin class _$FlowLineElementCopyWith<$Res> implements $FlowLineElementCopyWith<$Res> {
  factory _$FlowLineElementCopyWith(_FlowLineElement value, $Res Function(_FlowLineElement) _then) = __$FlowLineElementCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: "enabled") bool enabled,@JsonKey(name: "type") String type,@JsonKey(name: "provider") String provider,@JsonKey(name: "endpoint") String? endpoint,@JsonKey(name: "dns") String? dns,@JsonKey(name: "scanner") bool? scanner,@JsonKey(name: "scanner_type") String? scannerType,@JsonKey(name: "scanner_timeout") int? scannerTimeout,@JsonKey(name: "psiphon") bool? psiphon,@JsonKey(name: "psiphon_country") String? psiphonCountry,@JsonKey(name: "gool") bool? gool,@JsonKey(name: "url") String? url
});




}
/// @nodoc
class __$FlowLineElementCopyWithImpl<$Res>
    implements _$FlowLineElementCopyWith<$Res> {
  __$FlowLineElementCopyWithImpl(this._self, this._then);

  final _FlowLineElement _self;
  final $Res Function(_FlowLineElement) _then;

/// Create a copy of FlowLineElement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? type = null,Object? provider = null,Object? endpoint = freezed,Object? dns = freezed,Object? scanner = freezed,Object? scannerType = freezed,Object? scannerTimeout = freezed,Object? psiphon = freezed,Object? psiphonCountry = freezed,Object? gool = freezed,Object? url = freezed,}) {
  return _then(_FlowLineElement(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,endpoint: freezed == endpoint ? _self.endpoint : endpoint // ignore: cast_nullable_to_non_nullable
as String?,dns: freezed == dns ? _self.dns : dns // ignore: cast_nullable_to_non_nullable
as String?,scanner: freezed == scanner ? _self.scanner : scanner // ignore: cast_nullable_to_non_nullable
as bool?,scannerType: freezed == scannerType ? _self.scannerType : scannerType // ignore: cast_nullable_to_non_nullable
as String?,scannerTimeout: freezed == scannerTimeout ? _self.scannerTimeout : scannerTimeout // ignore: cast_nullable_to_non_nullable
as int?,psiphon: freezed == psiphon ? _self.psiphon : psiphon // ignore: cast_nullable_to_non_nullable
as bool?,psiphonCountry: freezed == psiphonCountry ? _self.psiphonCountry : psiphonCountry // ignore: cast_nullable_to_non_nullable
as String?,gool: freezed == gool ? _self.gool : gool // ignore: cast_nullable_to_non_nullable
as bool?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Version {

@JsonKey(name: "github") String get github;@JsonKey(name: "testFlight") String get testFlight;@JsonKey(name: "appleStore") String get appleStore;@JsonKey(name: "googlePlay") String get googlePlay;@JsonKey(name: "microsoftStore") String get microsoftStore;
/// Create a copy of Version
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VersionCopyWith<Version> get copyWith => _$VersionCopyWithImpl<Version>(this as Version, _$identity);

  /// Serializes this Version to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Version&&(identical(other.github, github) || other.github == github)&&(identical(other.testFlight, testFlight) || other.testFlight == testFlight)&&(identical(other.appleStore, appleStore) || other.appleStore == appleStore)&&(identical(other.googlePlay, googlePlay) || other.googlePlay == googlePlay)&&(identical(other.microsoftStore, microsoftStore) || other.microsoftStore == microsoftStore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,github,testFlight,appleStore,googlePlay,microsoftStore);

@override
String toString() {
  return 'Version(github: $github, testFlight: $testFlight, appleStore: $appleStore, googlePlay: $googlePlay, microsoftStore: $microsoftStore)';
}


}

/// @nodoc
abstract mixin class $VersionCopyWith<$Res>  {
  factory $VersionCopyWith(Version value, $Res Function(Version) _then) = _$VersionCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "github") String github,@JsonKey(name: "testFlight") String testFlight,@JsonKey(name: "appleStore") String appleStore,@JsonKey(name: "googlePlay") String googlePlay,@JsonKey(name: "microsoftStore") String microsoftStore
});




}
/// @nodoc
class _$VersionCopyWithImpl<$Res>
    implements $VersionCopyWith<$Res> {
  _$VersionCopyWithImpl(this._self, this._then);

  final Version _self;
  final $Res Function(Version) _then;

/// Create a copy of Version
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? github = null,Object? testFlight = null,Object? appleStore = null,Object? googlePlay = null,Object? microsoftStore = null,}) {
  return _then(_self.copyWith(
github: null == github ? _self.github : github // ignore: cast_nullable_to_non_nullable
as String,testFlight: null == testFlight ? _self.testFlight : testFlight // ignore: cast_nullable_to_non_nullable
as String,appleStore: null == appleStore ? _self.appleStore : appleStore // ignore: cast_nullable_to_non_nullable
as String,googlePlay: null == googlePlay ? _self.googlePlay : googlePlay // ignore: cast_nullable_to_non_nullable
as String,microsoftStore: null == microsoftStore ? _self.microsoftStore : microsoftStore // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Version].
extension VersionPatterns on Version {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Version value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Version() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Version value)  $default,){
final _that = this;
switch (_that) {
case _Version():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Version value)?  $default,){
final _that = this;
switch (_that) {
case _Version() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: "github")  String github, @JsonKey(name: "testFlight")  String testFlight, @JsonKey(name: "appleStore")  String appleStore, @JsonKey(name: "googlePlay")  String googlePlay, @JsonKey(name: "microsoftStore")  String microsoftStore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Version() when $default != null:
return $default(_that.github,_that.testFlight,_that.appleStore,_that.googlePlay,_that.microsoftStore);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: "github")  String github, @JsonKey(name: "testFlight")  String testFlight, @JsonKey(name: "appleStore")  String appleStore, @JsonKey(name: "googlePlay")  String googlePlay, @JsonKey(name: "microsoftStore")  String microsoftStore)  $default,) {final _that = this;
switch (_that) {
case _Version():
return $default(_that.github,_that.testFlight,_that.appleStore,_that.googlePlay,_that.microsoftStore);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: "github")  String github, @JsonKey(name: "testFlight")  String testFlight, @JsonKey(name: "appleStore")  String appleStore, @JsonKey(name: "googlePlay")  String googlePlay, @JsonKey(name: "microsoftStore")  String microsoftStore)?  $default,) {final _that = this;
switch (_that) {
case _Version() when $default != null:
return $default(_that.github,_that.testFlight,_that.appleStore,_that.googlePlay,_that.microsoftStore);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Version implements Version {
  const _Version({@JsonKey(name: "github") required this.github, @JsonKey(name: "testFlight") required this.testFlight, @JsonKey(name: "appleStore") required this.appleStore, @JsonKey(name: "googlePlay") required this.googlePlay, @JsonKey(name: "microsoftStore") required this.microsoftStore});
  factory _Version.fromJson(Map<String, dynamic> json) => _$VersionFromJson(json);

@override@JsonKey(name: "github") final  String github;
@override@JsonKey(name: "testFlight") final  String testFlight;
@override@JsonKey(name: "appleStore") final  String appleStore;
@override@JsonKey(name: "googlePlay") final  String googlePlay;
@override@JsonKey(name: "microsoftStore") final  String microsoftStore;

/// Create a copy of Version
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VersionCopyWith<_Version> get copyWith => __$VersionCopyWithImpl<_Version>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VersionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Version&&(identical(other.github, github) || other.github == github)&&(identical(other.testFlight, testFlight) || other.testFlight == testFlight)&&(identical(other.appleStore, appleStore) || other.appleStore == appleStore)&&(identical(other.googlePlay, googlePlay) || other.googlePlay == googlePlay)&&(identical(other.microsoftStore, microsoftStore) || other.microsoftStore == microsoftStore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,github,testFlight,appleStore,googlePlay,microsoftStore);

@override
String toString() {
  return 'Version(github: $github, testFlight: $testFlight, appleStore: $appleStore, googlePlay: $googlePlay, microsoftStore: $microsoftStore)';
}


}

/// @nodoc
abstract mixin class _$VersionCopyWith<$Res> implements $VersionCopyWith<$Res> {
  factory _$VersionCopyWith(_Version value, $Res Function(_Version) _then) = __$VersionCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: "github") String github,@JsonKey(name: "testFlight") String testFlight,@JsonKey(name: "appleStore") String appleStore,@JsonKey(name: "googlePlay") String googlePlay,@JsonKey(name: "microsoftStore") String microsoftStore
});




}
/// @nodoc
class __$VersionCopyWithImpl<$Res>
    implements _$VersionCopyWith<$Res> {
  __$VersionCopyWithImpl(this._self, this._then);

  final _Version _self;
  final $Res Function(_Version) _then;

/// Create a copy of Version
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? github = null,Object? testFlight = null,Object? appleStore = null,Object? googlePlay = null,Object? microsoftStore = null,}) {
  return _then(_Version(
github: null == github ? _self.github : github // ignore: cast_nullable_to_non_nullable
as String,testFlight: null == testFlight ? _self.testFlight : testFlight // ignore: cast_nullable_to_non_nullable
as String,appleStore: null == appleStore ? _self.appleStore : appleStore // ignore: cast_nullable_to_non_nullable
as String,googlePlay: null == googlePlay ? _self.googlePlay : googlePlay // ignore: cast_nullable_to_non_nullable
as String,microsoftStore: null == microsoftStore ? _self.microsoftStore : microsoftStore // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
