class HashChainVerifyResult {
  final int checked;
  final List<String> brokenIds;
  final DateTime verifiedAt;

  HashChainVerifyResult({
    required this.checked,
    required this.brokenIds,
    required this.verifiedAt,
  });

  bool get isHealthy => brokenIds.isEmpty;
  int get brokenCount => brokenIds.length;
}
