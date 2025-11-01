import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'speed_test_api.g.dart';

/// Retrofit API interface for Cloudflare speed test following official protocol
@RestApi(baseUrl: 'https://speed.cloudflare.com')
abstract class SpeedTestApi {
  factory SpeedTestApi(Dio dio, {String baseUrl}) = _SpeedTestApi;

  /// Download test - get data from Cloudflare with specific bytes
  @GET('/__down')
  @DioResponseType(ResponseType.bytes)
  Future<HttpResponse<List<int>>> downloadTest({
    @Query('bytes') required int bytes,
    @Query('measId') required String measurementId,
    @Query('during') String? during,
    @SendProgress() ProgressCallback? onSendProgress,
    @ReceiveProgress() ProgressCallback? onReceiveProgress,
  });

  /// Upload test - send raw data to Cloudflare
  @POST('/__up')
  Future<HttpResponse<dynamic>> uploadTest(
    @Body() Stream<List<int>> data, {
    @Header('Content-Type') String contentType = 'application/octet-stream',
    @Header('Content-Length') required int contentLength,
    @Query('measId') required String measurementId,
    @Query('during') String? during,
    @SendProgress() ProgressCallback? onSendProgress,
    @ReceiveProgress() ProgressCallback? onReceiveProgress,
  });

  /// Latency test - minimal ping to Cloudflare
  @GET('/__down')
  Future<HttpResponse<dynamic>> latencyTest({
    @Query('bytes') int bytes = 0,
    @Query('measId') required String measurementId,
  });

  /// Log measurement results to Cloudflare
  @POST('/__log')
  Future<HttpResponse<dynamic>> logMeasurement({
    @Body() required Map<String, dynamic> logData,
  });

  /// Get TURN server credentials for packet loss testing
  @GET('/__turn')
  Future<HttpResponse<dynamic>> getTurnCredentials();

  /// Get Cloudflare trace information (mey be useful for diagnostics)
  @GET('/cdn-cgi/trace')
  Future<HttpResponse<String>> getTrace();
}
