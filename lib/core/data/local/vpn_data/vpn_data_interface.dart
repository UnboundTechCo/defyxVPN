abstract class IVPNData {
  bool get isVPNEnabled;
  Future<void> enableVPN();
  Future<void> disableVPN();
}