abstract interface class IFlowlineService {
  Future<String> getFlowline();
  Future<String> getCachedFlowLine();
  Future<void> saveFlowline({required bool loadFromCache, String? flowLine});
  
}
