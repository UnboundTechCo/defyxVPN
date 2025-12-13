abstract interface class IFlowlineService {
  Future<String> getFlowline();
  Future<String> getCachedFlowLine();
  Future<void> saveFlowline(bool offlineMode);
  
}
