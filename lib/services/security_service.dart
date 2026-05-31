class SecurityService {
  Future<void> initializeKeys({bool force = false}) async {}
  Future<void> forceRefreshKeys() async {}
  Future<String?> getDatabaseKey() async {
    return 'dummy_key'; // Stub for compatibility
  }
  void reset() {}
  Future<void> checkAndReplenishPreKeys() async {}
}
