abstract interface class IFlowlineService {
  Future<String> getFlowline();
  Future<void> saveFlowline();
}
