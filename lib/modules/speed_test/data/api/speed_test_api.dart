import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'speed_test_api.g.dart';

/// Retrofit API interface for Cloudflare speed test
@RestApi(baseUrl: 'https://speed.cloudflare.com')
abstract class SpeedTestApi {
  factory SpeedTestApi(Dio dio, {String baseUrl}) = _SpeedTestApi;

  /// Download test - get data from Cloudflare
  @GET('/__down')
  Future<HttpResponse<List<int>>> downloadTest({
    @Query('bytes') required int bytes,
    @SendProgress() ProgressCallback? onSendProgress,
    @ReceiveProgress() ProgressCallback? onReceiveProgress,
  });

  /// Upload test - send data to Cloudflare
  @POST('/__up')
  Future<HttpResponse<dynamic>> uploadTest({
    @Part() required List<int> file,
    @SendProgress() ProgressCallback? onSendProgress,
    @ReceiveProgress() ProgressCallback? onReceiveProgress,
  });

  /// Latency test - ping Cloudflare with minimal data
  @GET('/__down')
  Future<HttpResponse<dynamic>> latencyTest({
    @Query('bytes') int bytes = 0,
  });
}
