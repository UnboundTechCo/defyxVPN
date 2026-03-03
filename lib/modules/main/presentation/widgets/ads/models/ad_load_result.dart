/// Result of an ad loading operation
class AdLoadResult {
  final bool success;
  final String? errorCode;
  final String? errorMessage;
  final int attemptCount;
  
  const AdLoadResult({
    required this.success,
    this.errorCode,
    this.errorMessage,
    this.attemptCount = 1,
  });
  
  const AdLoadResult.success({this.attemptCount = 1})
      : success = true,
        errorCode = null,
        errorMessage = null;
  
  const AdLoadResult.failure({
    required this.errorCode,
    required this.errorMessage,
    this.attemptCount = 1,
  }) : success = false;
}
