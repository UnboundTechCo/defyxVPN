abstract interface class IFlowlineService {
  Future<String> getFlowline();
  Future<String> getCachedFlowLine();
  Future<String> decodeAndVerifyFlowline(String flowLine);
  Future<void> saveFlowline({required bool offlineMode, String? flowLine});
  
}
