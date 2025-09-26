abstract interface class ISecureStorage {
  Future<void> write(String key, String value);
  Future<void> writeMap(String key, Map<String, dynamic> map);
  Future<Map<String, dynamic>> readMap(String key);

  Future<String?> read(String key);

  Future<void> delete(String key);
}
