abstract interface class IFlowlineService {
  Future<String> getFlowline();
  Future<void> saveFlowline();
  Future<Map<String, dynamic>> getStoredFlowlineOrDefault();
  Future<void> initializeOfflineMode();
}
